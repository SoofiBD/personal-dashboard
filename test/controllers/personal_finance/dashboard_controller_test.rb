require "test_helper"

class PersonalFinance::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.dashboard_owner.update!(onboarded_at: Time.current)
  end

  test "dashboard is available without an authentication flow" do
    get finance_root_path

    assert_response :success
    assert_select "h1", I18n.t("dashboard.title")
    assert_equal 1, User.count
  end

  test "dashboard renders interactive cash flow chart and category bars with data" do
    user = User.dashboard_owner
    account = PersonalFinance::Account.create!(user: user, name: "Bank", kind: "bank", opening_balance: 0)
    expense_cat = PersonalFinance::Category.create!(user: user, name: "Food", kind: "expense", color: "#3B82F6")
    income_cat = PersonalFinance::Category.create!(user: user, name: "Salary", kind: "income", color: "#10B981")

    PersonalFinance::Transaction.create!(user: user, account: account, category: income_cat, kind: "income", amount: 5000, occurred_on: Date.current)
    PersonalFinance::Transaction.create!(user: user, account: account, category: expense_cat, kind: "expense", amount: 1200, occurred_on: Date.current)
    PersonalFinance::Transaction.create!(user: user, account: account, category: expense_cat, kind: "expense", amount: 900, occurred_on: 1.month.ago)

    budget = PersonalFinance::BudgetPeriod.create!(
      user: user, starts_on: Date.current.beginning_of_month, ends_on: Date.current.end_of_month, planned_income: 1000
    )
    budget.allocations.create!(category: expense_cat, planned_amount: 500)

    get finance_root_path

    assert_response :success
    assert_select "canvas#cashflow-chart"
    assert_select "script#cashflow-chart-data"
    assert_select "table#cashflow-data-table"
    assert_select ".category-bars .cat-bar-row"
  end

  test "dashboard shows empty state for chart when no transactions exist" do
    get finance_root_path

    assert_response :success
    assert_select "canvas#cashflow-chart", count: 0
    assert_select ".empty-state"
  end

  test "spending report renders category distribution, comparison, and sub-category drill-down data" do
    user = User.dashboard_owner
    account = PersonalFinance::Account.create!(user: user, name: "Bank", kind: "bank", opening_balance: 0)
    food = PersonalFinance::Category.create!(user: user, name: "Food", kind: "expense", color: "#3B82F6")
    groceries = PersonalFinance::Category.create!(user: user, parent: food, name: "Groceries", kind: "expense", color: "#60A5FA")
    PersonalFinance::Transaction.create!(user: user, account: account, category: groceries, kind: "expense", amount: 1200, occurred_on: Date.current)
    PersonalFinance::Transaction.create!(user: user, account: account, category: food, kind: "expense", amount: 300, occurred_on: 1.month.ago)

    get finance_spending_report_path(from: Date.current.beginning_of_month, to: Date.current.end_of_month)

    assert_response :success
    assert_select "canvas#spending-donut-chart"
    assert_select "script#spending-report-data"
    assert_select "button[data-spending-category-id='#{food.id}']", text: /Food/
    assert_select "#subcategory-breakdown"
  end

  test "cash flow forecast renders editable assumptions and projected balance chart" do
    get finance_cash_flow_forecast_path(months: 3, baseline_income: 5000, baseline_expenses: 2000)

    assert_response :success
    assert_select "canvas#cash-flow-forecast-chart"
    assert_select "input[name='baseline_income'][value='5000.0']"
    assert_select "table.forecast-table"
  end
end
