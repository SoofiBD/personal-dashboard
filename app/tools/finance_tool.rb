# frozen_string_literal: true

class FinanceTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :get_monthly_summary, description: 'Current month expense/income totals by category' do
  end

  define_function :create_expense, description: 'Create expense. Params: amount, category_name, description' do
    property :amount, type: 'number', description: 'Amount', required: true
    property :category_name, type: 'string', description: 'Category name', required: true
    property :description, type: 'string', description: 'Description', required: true
  end

  define_function :create_income, description: 'Create income. Params: amount, category_name, description' do
    property :amount, type: 'number', description: 'Amount', required: true
    property :category_name, type: 'string', description: 'Category name', required: true
    property :description, type: 'string', description: 'Description', required: true
  end

  define_function :list_accounts, description: 'All accounts with balances' do
  end

  define_function :get_recent_transactions, description: 'Transactions from last N days (default 7)' do
    property :days, type: 'integer', description: 'Number of days', required: false
  end

  define_function :get_budget_status, description: 'Budget vs actual for current month' do
  end

  define_function :list_subscriptions, description: 'Active subscriptions with costs' do
  end

  define_function :get_debts, description: 'Active debts overview' do
  end

  define_function :get_savings_goals, description: 'Savings goals with progress' do
  end

  def get_monthly_summary
    range = current_month_range
    expenses = user.finance_transactions.expense.during(range)
                   .joins(:category).group('finance_categories.name').sum(:amount)
    income = user.finance_transactions.income.during(range)
                 .joins(:category).group('finance_categories.name').sum(:amount)

    total_expense = expenses.values.sum
    total_income = income.values.sum

    tool_response(content: {
                    total_expense: total_expense.to_f,
                    total_income: total_income.to_f,
                    net: (total_income - total_expense).to_f,
                    by_category: {
                      expenses: expenses.transform_values(&:to_f),
                      income: income.transform_values(&:to_f)
                    }
                  })
  end

  def create_expense(amount:, category_name:, description:)
    category = find_category(category_name)
    return tool_response(content: { error: "Category '#{category_name}' not found" }) unless category

    account = find_default_account
    return tool_response(content: { error: 'No active account found' }) unless account

    transaction = user.finance_transactions.create!(
      kind: 'expense',
      amount: amount,
      category: category,
      account: account,
      occurred_on: Date.current,
      note: description
    )

    tool_response(content: {
                    success: true,
                    transaction: { id: transaction.id, amount: amount, category: category_name, description: description,
                                   date: transaction.occurred_on }
                  })
  end

  def create_income(amount:, category_name:, description:)
    category = find_category(category_name)
    return tool_response(content: { error: "Category '#{category_name}' not found" }) unless category

    account = find_default_account
    return tool_response(content: { error: 'No active account found' }) unless account

    transaction = user.finance_transactions.create!(
      kind: 'income',
      amount: amount,
      category: category,
      account: account,
      occurred_on: Date.current,
      note: description
    )

    tool_response(content: {
                    success: true,
                    transaction: { id: transaction.id, amount: amount, category: category_name, description: description,
                                   date: transaction.occurred_on }
                  })
  end

  def list_accounts
    accounts = user.financial_accounts.active.map do |acc|
      { name: acc.name, kind: acc.kind, balance: acc.current_balance.to_f, currency: acc.currency }
    end
    tool_response(content: accounts)
  end

  def get_recent_transactions(days: 7)
    start_date = days.days.ago.to_date
    transactions = user.finance_transactions
                       .where(occurred_on: start_date..Date.current)
                       .includes(:category, :account)
                       .order(occurred_on: :desc)
                       .limit(50)
                       .map do |t|
                         { date: t.occurred_on, amount: t.amount.to_f, kind: t.kind, category: t.category&.name,
                           account: t.account&.name, note: t.note }
                       end
    tool_response(content: transactions)
  end

  def get_budget_status
    period = user.finance_budget_periods.where('starts_on <= ? AND ends_on >= ?', Date.current, Date.current).first
    return tool_response(content: { error: 'No active budget period' }) unless period

    allocations = period.budget_allocations.includes(:category).map do |a|
      spent = user.finance_transactions.expense.during(period.starts_on..period.ends_on)
                  .where(category: a.category).sum(:amount).to_f
      { category: a.category.name, budget: a.planned_amount.to_f, spent: spent,
        remaining: (a.planned_amount.to_f - spent).round(2) }
    end

    total_budget = allocations.sum { |a| a[:budget] }
    total_spent = allocations.sum { |a| a[:spent] }

    tool_response(content: {
                    period: { start: period.starts_on, end: period.ends_on },
                    total_budget: total_budget,
                    total_spent: total_spent,
                    remaining: (total_budget - total_spent).round(2),
                    by_category: allocations
                  })
  end

  def list_subscriptions
    subs = user.finance_subscriptions.active.map do |s|
      { name: s.name, amount: s.amount.to_f, interval: s.billing_interval, monthly_cost: s.monthly_cost.to_f,
        renewal: s.renewal_on }
    end
    tool_response(content: subs)
  end

  def get_debts
    debts = user.finance_debts.active.map do |d|
      { name: d.name, remaining: d.remaining_amount.to_f, monthly: d.monthly_payment.to_f,
        interest: d.interest_rate.to_f, next_payment: d.next_payment_on }
    end
    tool_response(content: debts)
  end

  def get_savings_goals
    goals = user.finance_savings_goals.active.map do |g|
      { name: g.name, target: g.target_amount.to_f, saved: g.saved_amount.to_f, remaining: g.remaining_amount.to_f,
        monthly: g.monthly_contribution.to_f, est_months: g.estimated_months }
    end
    tool_response(content: goals)
  end

  private

  attr_reader :user

  def current_month_range
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month
    start_date..end_date
  end

  def find_category(name)
    PersonalFinance::Category.find_by(user: user, name: name)
  end

  def find_default_account
    PersonalFinance::Account.find_by(user: user, is_active: true)
  end

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
