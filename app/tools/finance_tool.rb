# frozen_string_literal: true

class FinanceTool < AiTool
  ACTIONS = {
    "finance.create_expense" => :apply_create_expense,
    "finance.create_income" => :apply_create_income,
    "finance.update_transaction" => :apply_update_transaction,
    "finance.delete_transaction" => :apply_delete_transaction,
    "finance.create_subscription" => :apply_create_subscription,
    "finance.delete_subscription" => :apply_delete_subscription
  }.freeze

  function :get_monthly_summary, "Current month expense/income totals by category"
  function :list_accounts, "All active accounts with balances"
  function :list_categories, "Expense and income category names; use these exact names when recording transactions"
  function :get_recent_transactions, "Transactions from the last N days (default 7, max 90)",
    days: {type: "integer", description: "Number of days"}
  function :get_budget_status, "Budget vs actual for the current budget period"
  function :list_subscriptions, "Active subscriptions with ids and costs"
  function :get_debts, "Active debts overview"
  function :get_savings_goals, "Savings goals with progress"
  function :create_expense, "Record an expense immediately (no confirmation step)",
    required: %i[amount category_name description],
    amount: {type: "number", description: "Positive amount"},
    category_name: {type: "string", description: "Exact expense category name from list_categories"},
    description: {type: "string", description: "Description"},
    occurred_on: {type: "string", description: "Date YYYY-MM-DD, default today, not in the future"},
    account_name: {type: "string", description: "Account name from list_accounts, default the first active account"}
  function :create_income, "Record an income immediately (no confirmation step)",
    required: %i[amount category_name description],
    amount: {type: "number", description: "Positive amount"},
    category_name: {type: "string", description: "Exact income category name from list_categories"},
    description: {type: "string", description: "Description"},
    occurred_on: {type: "string", description: "Date YYYY-MM-DD, default today, not in the future"},
    account_name: {type: "string", description: "Account name from list_accounts, default the first active account"}
  function :create_subscription, "Add a recurring subscription immediately (no confirmation step)",
    required: %i[name amount billing_interval],
    name: {type: "string", description: "Subscription name, e.g. Netflix"},
    amount: {type: "number", description: "Positive amount per billing interval"},
    billing_interval: {type: "string", enum: %w[monthly yearly], description: "monthly or yearly"},
    renewal_on: {type: "string", description: "Next renewal date YYYY-MM-DD, optional"}
  function :delete_subscription, "Propose removing a subscription; user confirmation is required",
    required: %i[id],
    id: {type: "string", description: "Subscription UUID from list_subscriptions"}
  function :update_transaction, "Propose updating a non-transfer transaction; user confirmation is required",
    required: %i[id],
    id: {type: "string", description: "Transaction UUID"},
    amount: {type: "number", description: "New amount"},
    description: {type: "string", description: "New description"},
    occurred_on: {type: "string", description: "New date YYYY-MM-DD"}
  function :delete_transaction, "Propose deleting a non-transfer transaction; user confirmation is required",
    required: %i[id],
    id: {type: "string", description: "Transaction UUID"}

  def get_monthly_summary
    range = Date.current.all_month
    expenses = user.finance_transactions.expense.during(range).joins(:category).group("finance_categories.name").sum(:amount)
    income = user.finance_transactions.income.during(range).joins(:category).group("finance_categories.name").sum(:amount)
    total_expense = expenses.values.sum
    total_income = income.values.sum

    {
      total_expense: total_expense.to_f,
      total_income: total_income.to_f,
      net: (total_income - total_expense).to_f,
      by_category: {expenses: expenses.transform_values(&:to_f), income: income.transform_values(&:to_f)}
    }
  end

  def list_accounts
    user.financial_accounts.active.map do |account|
      {name: account.name, kind: account.kind, balance: account.current_balance.to_f, currency: account.currency}
    end
  end

  def list_categories
    user.finance_categories.order(:name).pluck(:kind, :name).group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end

  def get_recent_transactions(days: 7)
    user.finance_transactions
      .where(occurred_on: days.to_i.clamp(1, 90).days.ago.to_date..Date.current)
      .includes(:category, :account)
      .order(occurred_on: :desc)
      .limit(50)
      .map do |t|
        {id: t.id, date: t.occurred_on, amount: t.amount.to_f, kind: t.kind, category: t.category&.name, account: t.account&.name, note: t.note}
      end
  end

  def get_budget_status
    period = user.finance_budget_periods.where("starts_on <= ? AND ends_on >= ?", Date.current, Date.current).first
    return {error: "No active budget period"} unless period

    spending = user.finance_transactions.expense.during(period.starts_on..period.ends_on).where.not(category_id: nil).group(:category_id).sum(:amount)
    allocations = period.allocations.includes(:category).map do |a|
      spent = spending.fetch(a.category_id, 0).to_f
      {category: a.category.name, budget: a.planned_amount.to_f, spent: spent, remaining: (a.planned_amount.to_f - spent).round(2)}
    end
    total_budget = allocations.sum { |a| a[:budget] }
    total_spent = allocations.sum { |a| a[:spent] }

    {
      period: {start: period.starts_on, end: period.ends_on},
      total_budget: total_budget,
      total_spent: total_spent,
      remaining: (total_budget - total_spent).round(2),
      by_category: allocations
    }
  end

  def list_subscriptions
    user.finance_subscriptions.active.map do |s|
      {id: s.id, name: s.name, amount: s.amount.to_f, interval: s.billing_interval, monthly_cost: s.monthly_cost.to_f, renewal: s.renewal_on}
    end
  end

  def get_debts
    user.finance_debts.active.map do |d|
      {name: d.name, remaining: d.remaining_amount.to_f, monthly: d.monthly_payment.to_f, interest: d.interest_rate.to_f, next_payment: d.next_payment_on}
    end
  end

  def get_savings_goals
    user.finance_savings_goals.active.map do |g|
      {name: g.name, target: g.target_amount.to_f, saved: g.saved_amount.to_f, remaining: g.remaining_amount.to_f,
       monthly: g.monthly_contribution.to_f, est_months: g.estimated_months}
    end
  end

  def create_expense(amount:, category_name:, description:, occurred_on: nil, account_name: nil)
    record_transaction("expense", amount, category_name, description, occurred_on, account_name)
  end

  def create_income(amount:, category_name:, description:, occurred_on: nil, account_name: nil)
    record_transaction("income", amount, category_name, description, occurred_on, account_name)
  end

  def create_subscription(name:, amount:, billing_interval:, renewal_on: nil)
    return {error: "No permission to edit finances"} unless user.can_manage_finances?
    return {error: "Amount must be positive"} unless amount.to_d.positive?
    return {error: "billing_interval must be monthly or yearly"} unless %w[monthly yearly].include?(billing_interval)
    renewal = parse_date(renewal_on)
    return {error: "renewal_on must be YYYY-MM-DD"} if renewal_on.present? && renewal.nil?

    payload = {name: name.to_s.strip.first(100), amount: amount, billing_interval: billing_interval, renewal_on: renewal&.iso8601}.compact
    label = (billing_interval == "monthly") ? "aylık" : "yıllık"
    perform("finance.create_subscription", payload, "Abonelik: #{payload[:name]} · #{amount} #{label}")
  end

  def delete_subscription(id:)
    subscription = user.finance_subscriptions.find_by(id: id)
    return {error: "Subscription not found"} unless subscription

    propose("finance.delete_subscription", {id: subscription.id}, "Aboneliği sil: #{subscription.name} · #{subscription.amount}")
  end

  def update_transaction(id:, amount: nil, description: nil, occurred_on: nil)
    transaction = user.finance_transactions.find_by(id: id)
    return {error: "Transaction not found"} unless transaction
    return {error: "Paired transfers must be recreated"} if transaction.transfer_group_id.present?
    payload = {id: transaction.id, amount: amount, note: description, occurred_on: occurred_on}.compact
    return {error: "No change supplied"} if payload.except(:id).empty?

    propose("finance.update_transaction", payload, "Finans hareketini güncelle: #{transaction_label(transaction)}")
  end

  def delete_transaction(id:)
    transaction = user.finance_transactions.find_by(id: id)
    return {error: "Transaction not found"} unless transaction
    return {error: "Paired transfers must be deleted from the panel"} if transaction.transfer_group_id.present?

    propose("finance.delete_transaction", {id: transaction.id}, "Finans hareketini sil: #{transaction.amount} · #{transaction_label(transaction)}")
  end

  def apply_create_expense(payload) = create_transaction("expense", payload)

  def apply_create_income(payload) = create_transaction("income", payload)

  def apply_update_transaction(payload)
    require_finance_permission!
    transaction = editable_transaction(payload)
    attributes = payload.slice("amount", "note", "occurred_on").compact_blank
    attributes["amount"] = BigDecimal(attributes["amount"].to_s) if attributes["amount"]
    transaction.update!(attributes)
    {record_type: "transaction", record_id: transaction.id}
  end

  def apply_delete_transaction(payload)
    require_finance_permission!
    transaction = editable_transaction(payload)
    transaction.destroy!
    {record_type: "transaction", record_id: transaction.id}
  end

  def apply_create_subscription(payload)
    require_finance_permission!
    subscription = user.finance_subscriptions.create!(payload.slice("name", "amount", "billing_interval", "renewal_on"))
    {record_type: "subscription", record_id: subscription.id}
  end

  def apply_delete_subscription(payload)
    require_finance_permission!
    subscription = user.finance_subscriptions.find(payload.fetch("id"))
    subscription.destroy!
    {record_type: "subscription", record_id: subscription.id}
  end

  private

  def record_transaction(kind, amount, category_name, description, occurred_on, account_name)
    return {error: "No permission to edit finances"} unless user.can_manage_finances?
    return {error: "Amount must be positive"} unless amount.to_d.positive?
    unless find_category(category_name, kind)
      return {error: "Unknown #{kind} category '#{category_name}'", available_categories: list_categories.fetch(kind, [])}
    end
    date = occurred_on.present? ? parse_date(occurred_on) : Date.current
    return {error: "occurred_on must be YYYY-MM-DD and not in the future"} if date.nil? || date > Date.current
    return {error: "Unknown account '#{account_name}'", available_accounts: list_accounts.map { |a| a[:name] }} unless find_account(account_name)

    label = (kind == "expense") ? "Gider" : "Gelir"
    payload = {amount: amount, category_name: category_name, description: description.to_s.first(500), occurred_on: date.iso8601, account_name: account_name.presence}.compact
    perform("finance.create_#{kind}", payload, "#{label}: #{amount} · #{category_name} · #{description} · #{date.iso8601}")
  end

  def create_transaction(kind, payload)
    require_finance_permission!
    amount = BigDecimal(payload.fetch("amount").to_s)
    raise AiActionExecutor::Error, "Tutar sıfırdan büyük olmalıdır." unless amount.positive?
    category = find_category(payload.fetch("category_name"), kind) || raise(ActiveRecord::RecordNotFound)
    account = find_account(payload["account_name"]) || raise(ActiveRecord::RecordNotFound)
    occurred_on = parse_date(payload["occurred_on"]) || Date.current
    transaction = user.finance_transactions.create!(kind: kind, amount: amount, category: category, account: account, occurred_on: occurred_on, note: payload.fetch("description"))
    {record_type: "transaction", record_id: transaction.id}
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def editable_transaction(payload)
    transaction = user.finance_transactions.find(payload.fetch("id"))
    raise AiActionExecutor::Error, "Bağlı transferler panelden düzenlenmelidir." if transaction.transfer_group_id.present?
    transaction
  end

  def transaction_label(transaction)
    transaction.note.presence || transaction.category&.name || transaction.id
  end

  def find_category(name, kind)
    PersonalFinance::Category.find_by(user: user, name: name, kind: kind)
  end

  def find_account(name)
    accounts = PersonalFinance::Account.where(user: user, is_active: true)
    name.present? ? accounts.find_by(name: name) : accounts.order(:created_at).first
  end
end
