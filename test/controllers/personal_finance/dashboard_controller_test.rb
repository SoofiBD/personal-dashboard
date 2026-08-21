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
end
