require "test_helper"

module PersonalFinanceModelFactory
  private

  def finance_user
    User.create!(name: "User #{SecureRandom.hex(4)}", currency: "TRY", time_zone: "Europe/Istanbul")
  end

  def account_for(user, name: "Cash", kind: :cash, opening_balance: 0)
    PersonalFinance::Account.create!(user: user, name: "#{name} #{SecureRandom.hex(3)}", kind: kind, opening_balance: opening_balance)
  end

  def category_for(user, kind: :expense, parent: nil)
    PersonalFinance::Category.create!(user: user, name: "Category #{SecureRandom.hex(3)}", kind: kind, color: "#2563EB", parent: parent)
  end

  def transaction_for(user, account:, category:, kind: :expense, amount: 100, occurred_on: Date.current)
    PersonalFinance::Transaction.create!(user: user, account: account, category: category, kind: kind, amount: amount, occurred_on: occurred_on)
  end
end

class PersonalFinance::AccountTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "calculates current and monthly historical balances" do
    user = finance_user
    account = account_for(user, opening_balance: 100)
    expense = category_for(user)
    income = category_for(user, kind: :income)
    transaction_for(user, account: account, category: income, kind: :income, amount: 50, occurred_on: 2.months.ago.to_date)
    transaction_for(user, account: account, category: expense, amount: 20, occurred_on: Date.current)

    assert_equal 130, account.current_balance.to_i
    assert_equal 3, account.balance_history(months: 3).size
    assert_equal 130, account.balance_history(months: 3).last[:balance].to_i
  end
end

class PersonalFinance::BudgetModelsTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "enforces monthly uniqueness and calculates allocation spending" do
    user = finance_user
    budget = PersonalFinance::BudgetPeriod.create!(user: user, starts_on: Date.current.beginning_of_month, ends_on: Date.current.end_of_month, planned_income: 1000)
    duplicate = PersonalFinance::BudgetPeriod.new(user: user, starts_on: budget.starts_on, ends_on: budget.ends_on, planned_income: 0)
    category = category_for(user)
    allocation = budget.allocations.create!(category: category, planned_amount: 300)
    transaction_for(user, account: account_for(user), category: category, amount: 125)

    assert_not duplicate.valid?
    assert_equal 125, allocation.spent.to_i
    assert_equal 175, allocation.remaining.to_i
    assert_equal 300, budget.planned_spending.to_i
    assert_equal 125, budget.actual_spending.to_i
  end

  test "rejects allocations for another user's or non-expense category" do
    user = finance_user
    budget = PersonalFinance::BudgetPeriod.create!(user: user, starts_on: Date.current.beginning_of_month, ends_on: Date.current.end_of_month, planned_income: 0)
    allocation = budget.allocations.build(category: category_for(finance_user), planned_amount: 1)

    assert_not allocation.valid?
    assert_includes allocation.errors[:category], "is invalid"
  end
end

class PersonalFinance::CategoryTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "builds hierarchy names and includes direct children" do
    user = finance_user
    parent = category_for(user)
    child = category_for(user, parent: parent)

    assert_equal "#{parent.name} › #{child.name}", child.full_name
    assert_equal [parent.id, child.id].sort, parent.self_and_descendant_ids.sort
  end

  test "rejects a category nested below one level" do
    user = finance_user
    parent = category_for(user)
    child = category_for(user, parent: parent)
    grandchild = PersonalFinance::Category.new(user: user, name: "Grandchild", kind: :expense, color: "#2563EB", parent: child)

    assert_not grandchild.valid?
    assert_includes grandchild.errors[:parent], "cannot be nested more than one level"
  end
end

class PersonalFinance::DebtModelsTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "updates debt balance and payoff date after a payment" do
    debt = PersonalFinance::Debt.create!(user: finance_user, name: "Loan", total_amount: 300, remaining_amount: 300, monthly_payment: 100, remaining_installments: 3, next_payment_on: Date.new(2026, 1, 15))

    assert_equal Date.new(2026, 3, 15), debt.payoff_date
    PersonalFinance::DebtPayment.create!(debt: debt, amount: 100, paid_on: Date.current)

    debt.reload
    assert_equal 200, debt.remaining_amount.to_i
    assert_equal 2, debt.remaining_installments
    assert_predicate debt, :active?
  end

  test "requires a positive payment amount" do
    debt = PersonalFinance::Debt.create!(user: finance_user, name: "Loan", total_amount: 1, remaining_amount: 1, monthly_payment: 1, remaining_installments: 1)
    payment = debt.payments.build(amount: 0, paid_on: Date.current)

    assert_not payment.valid?
  end
end

class PersonalFinance::SavingsGoalModelsTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "calculates saved amount, remaining amount, and estimated months" do
    goal = PersonalFinance::SavingsGoal.create!(user: finance_user, name: "Trip", target_amount: 1000, starting_amount: 100, monthly_contribution: 200)
    goal.contributions.create!(amount: 300, contributed_on: Date.current)

    assert_equal 400, goal.saved_amount.to_i
    assert_equal 600, goal.remaining_amount.to_i
    assert_equal 3, goal.estimated_months
  end

  test "requires positive goal contributions" do
    goal = PersonalFinance::SavingsGoal.create!(user: finance_user, name: "Trip", target_amount: 100, starting_amount: 0, monthly_contribution: 0)
    contribution = goal.contributions.build(amount: 0, contributed_on: Date.current)

    assert_not contribution.valid?
  end
end

class PersonalFinance::ExchangeRateTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "normalizes currencies and prevents duplicate or equal pairs" do
    user = finance_user
    rate = PersonalFinance::ExchangeRate.create!(user: user, base_currency: "try", quote_currency: "usd", rate: 0.03)
    duplicate = PersonalFinance::ExchangeRate.new(user: user, base_currency: "TRY", quote_currency: "USD", rate: 0.04)
    equal_pair = PersonalFinance::ExchangeRate.new(user: user, base_currency: "TRY", quote_currency: "TRY", rate: 1)

    assert_equal "TRY", rate.base_currency
    assert_not duplicate.valid?
    assert_not equal_pair.valid?
  end
end

class PersonalFinance::PurchasePlanTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "validates amounts and requires a goal owned by the plan user" do
    user = finance_user
    other_goal = PersonalFinance::SavingsGoal.create!(user: finance_user, name: "Other", target_amount: 100, starting_amount: 0, monthly_contribution: 0)
    plan = PersonalFinance::PurchasePlan.new(user: user, savings_goal: other_goal, name: "Laptop", price: 1000, down_payment: 100, monthly_cost: 75)

    assert_not plan.valid?
    assert_includes plan.errors[:savings_goal], "is invalid"
  end

  test "calculates installment scenarios from the configured down payment" do
    user = finance_user
    plan = PersonalFinance::PurchasePlan.create!(user: user, name: "Laptop", price: 1000, down_payment: 100, monthly_cost: 0)
    installment = plan.assessment.scenarios.find { |scenario| scenario[:key] == :installment_3 }

    assert_equal 100, installment[:down_payment]
    assert_equal 300, installment[:monthly_cost]
    assert_equal 1000, installment[:total]
  end
end

class PersonalFinance::NotificationTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "returns unread notifications newest first" do
    user = finance_user
    read = PersonalFinance::Notification.create!(user: user, kind: "read", title: "Read", body: "Done", read_at: Time.current)
    recent = PersonalFinance::Notification.create!(user: user, kind: "recent", title: "Recent", body: "New")
    older = PersonalFinance::Notification.create!(user: user, kind: "older", title: "Older", body: "Old", created_at: 1.day.ago)

    assert_equal [recent, older], PersonalFinance::Notification.unread.recent_first.to_a
    assert_predicate read, :read?
  end
end

class PersonalFinance::TransactionImportTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "persists mappings, preview state, and imported status" do
    user = finance_user
    import = PersonalFinance::TransactionImport.create!(user: user, account: account_for(user), source_csv: "date,amount\n2026-01-01,10", column_mapping: {"date" => "date"}, preview_rows: [{"amount" => "10"}])

    assert_equal "date", import.column_mapping["date"]
    assert_equal "10", import.preview_rows.first["amount"]
    assert_not_predicate import, :imported?
    import.update!(imported_at: Time.current)
    assert_predicate import, :imported?
  end
end

class PersonalFinance::TransactionTagTest < ActiveSupport::TestCase
  include PersonalFinanceModelFactory

  test "prevents assigning the same tag to a transaction twice" do
    user = finance_user
    account = account_for(user)
    category = category_for(user)
    transaction = transaction_for(user, account: account, category: category)
    tag = PersonalFinance::Tag.create!(user: user, name: "Essential")
    PersonalFinance::TransactionTag.create!(financial_transaction: transaction, tag: tag)
    duplicate = PersonalFinance::TransactionTag.new(financial_transaction: transaction, tag: tag)

    assert_not duplicate.valid?
  end
end
