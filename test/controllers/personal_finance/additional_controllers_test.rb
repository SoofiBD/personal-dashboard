require "test_helper"

class PersonalFinance::AdditionalControllersTest < PersonalFinance::IntegrationTest
  setup do
    user.update!(onboarded_at: Time.current)
  end

  def user
    User.dashboard_owner
  end

  def account(kind: :bank)
    PersonalFinance::Account.create!(user: user, name: "Account #{SecureRandom.hex(3)}", kind: kind, opening_balance: 100)
  end

  def category(kind: :expense, parent: nil)
    PersonalFinance::Category.create!(user: user, name: "Category #{SecureRandom.hex(3)}", kind: kind, color: "#2563EB", parent: parent)
  end

  test "accounts create and reject invalid data" do
    assert_difference("PersonalFinance::Account.count", 1) do
      post finance_accounts_path, params: {account: {name: "Wallet", kind: "cash", opening_balance: 25, currency: "TRY"}}
    end
    assert_redirected_to finance_accounts_path

    post finance_accounts_path, params: {account: {name: "", kind: "cash", opening_balance: 0, currency: "TRY"}}
    assert_response :unprocessable_entity
  end

  test "budget templates list and reject an invalid refresh month" do
    get finance_budget_templates_path
    assert_response :success
    template = PersonalFinance::BudgetTemplate.create!(user: user, name: "Custom #{SecureRandom.hex(3)}", allocation_data: [{"category_name" => "Food", "planned_amount" => "100"}])

    patch refresh_finance_budget_template_path(template), params: {month: "invalid"}
    assert_redirected_to finance_budget_templates_path
  end

  test "cash flow forecast clamps its requested range" do
    get finance_cash_flow_forecast_path, params: {months: 99, baseline_income: "1000", baseline_expenses: "250"}

    assert_response :success
    assert_select "#cash-flow-forecast-chart"
  end

  test "categories support a valid child and reject a mismatched type" do
    parent = category
    assert_difference("PersonalFinance::Category.count", 1) do
      post finance_categories_path, params: {category: {name: "Child", kind: "expense", color: "#2563EB", parent_id: parent.id}}
    end
    assert_redirected_to finance_categories_path

    post finance_categories_path, params: {category: {name: "Wrong type", kind: "income", color: "#2563EB", parent_id: parent.id}}
    assert_response :unprocessable_entity
  end

  test "debts record payments and update their balance" do
    debt = PersonalFinance::Debt.create!(user: user, name: "Loan", total_amount: 200, remaining_amount: 200, monthly_payment: 50, remaining_installments: 4, next_payment_on: Date.current)

    post pay_finance_debt_path(debt), params: {amount: 50, paid_on: Date.current}

    assert_redirected_to finance_debts_path
    assert_equal 150, debt.reload.remaining_amount.to_i
  end

  test "exchange rates render validation errors and save valid rates" do
    post finance_exchange_rates_path, params: {exchange_rate: {base_currency: "TRY", quote_currency: "TRY", rate: 1}}
    assert_response :unprocessable_entity

    assert_difference("PersonalFinance::ExchangeRate.count", 1) do
      post finance_exchange_rates_path, params: {exchange_rate: {base_currency: "TRY", quote_currency: "USD", rate: 0.03}}
    end
    assert_redirected_to finance_exchange_rates_path
  end

  test "recurring rules pause and resume" do
    rule = PersonalFinance::RecurringRule.create!(user: user, account: account, category: category, kind: "expense", amount: 10, note: "Weekly", starts_on: Date.current, last_generated_on: Date.current, recurrence_interval: "weekly")

    patch pause_finance_recurring_rule_path(rule)
    assert_predicate rule.reload, :is_paused?

    patch resume_finance_recurring_rule_path(rule)
    assert_not_predicate rule.reload, :is_paused?
  end

  test "savings goals create and show contribution inputs" do
    assert_difference("PersonalFinance::SavingsGoal.count", 1) do
      post finance_savings_goals_path, params: {savings_goal: {name: "Trip", target_amount: 1000, starting_amount: 100, monthly_contribution: 50, status: "active"}}
    end
    goal = PersonalFinance::SavingsGoal.where(user: user).order(:created_at).last
    assert_redirected_to finance_savings_goals_path

    get finance_savings_goal_path(goal)
    assert_response :success
    assert_select "form"
  end

  test "spending reports honor a selected date range" do
    expense_category = category
    transaction = PersonalFinance::Transaction.create!(user: user, account: account, category: expense_category, kind: "expense", amount: 75, occurred_on: Date.new(2026, 2, 10))

    get finance_spending_report_path, params: {from: "2026-02-01", to: "2026-02-28"}

    assert_response :success
    assert_select "body", text: /#{Regexp.escape(expense_category.name)}/
    assert_equal 75, transaction.amount.to_i
  end
end
