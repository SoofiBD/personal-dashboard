# frozen_string_literal: true

class FinanceTool < AiTool
  ACTIONS = {
    "finance.create_expense" => :apply_create_expense,
    "finance.create_income" => :apply_create_income,
    "finance.update_transaction" => :apply_update_transaction,
    "finance.delete_transaction" => :apply_delete_transaction
  }.freeze

  function :get_monthly_summary, "Current month expense/income totals by category"
  function :list_accounts, "All active accounts with balances"
  function :get_recent_transactions, "Transactions from the last N days (default 7, max 90)",
    days: {type: "integer", description: "Number of days"}
  function :get_budget_status, "Budget vs actual for the current budget period"
  function :list_subscriptions, "Active subscriptions with costs"
  function :get_debts, "Active debts overview"
  function :get_savings_goals, "Savings goals with progress"
  function :create_expense, "Propose a new expense on the active account; user confirmation is required",
    required: %i[amount category_name description],
    amount: {type: "number", description: "Positive amount"},
    category_name: {type: "string", description: "Existing expense category name"},
    description: {type: "string", description: "Description"}
  function :create_income, "Propose a new income on the active account; user confirmation is required",
    required: %i[amount category_name description],
    amount: {type: "number", description: "Positive amount"},
    category_name: {type: "string", description: "Existing income category name"},
    description: {type: "string", description: "Description"}
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
      {name: s.name, amount: s.amount.to_f, interval: s.billing_interval, monthly_cost: s.monthly_cost.to_f, renewal: s.renewal_on}
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

  def create_expense(amount:, category_name:, description:)
    propose_transaction("expense", amount, category_name, description)
  end

  def create_income(amount:, category_name:, description:)
    propose_transaction("income", amount, category_name, description)
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

  private

  def propose_transaction(kind, amount, category_name, description)
    return {error: "No permission to edit finances"} unless user.can_manage_finances?
    return {error: "Amount must be positive"} unless amount.to_d.positive?
    return {error: "Unknown #{kind} category '#{category_name}'"} unless find_category(category_name, kind)
    return {error: "No active account"} unless find_default_account

    label = (kind == "expense") ? "Gider" : "Gelir"
    propose("finance.create_#{kind}", {amount: amount, category_name: category_name, description: description}, "#{label}: #{amount} · #{category_name} · #{description}")
  end

  def create_transaction(kind, payload)
    require_finance_permission!
    amount = BigDecimal(payload.fetch("amount").to_s)
    raise AiActionExecutor::Error, "Tutar sıfırdan büyük olmalıdır." unless amount.positive?
    category = find_category(payload.fetch("category_name"), kind) || raise(ActiveRecord::RecordNotFound)
    account = find_default_account || raise(ActiveRecord::RecordNotFound)
    transaction = user.finance_transactions.create!(kind: kind, amount: amount, category: category, account: account, occurred_on: Date.current, note: payload.fetch("description"))
    {record_type: "transaction", record_id: transaction.id}
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

  # shortcut: proposals carry no account, so the first active account is used; add an account param when users have several.
  def find_default_account
    PersonalFinance::Account.find_by(user: user, is_active: true)
  end
end
