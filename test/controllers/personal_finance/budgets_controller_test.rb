require "test_helper"

class PersonalFinance::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.dashboard_owner.update!(onboarded_at: Time.current)
  end

  test "should get year budget view" do
    get finance_year_budget_path(year: 2026)
    assert_response :success
    assert_select "h1", "2026"
  end

  test "should return 404 for invalid year" do
    get finance_year_budget_path(year: 3000)
    assert_response :not_found
  end

  test "copy_previous copies allocations and planned income from previous month" do
    user = User.dashboard_owner
    category = PersonalFinance::Category.create!(user: user, name: "Food", kind: "expense", color: "#3B82F6")
    previous = PersonalFinance::BudgetPeriod.create!(
      user: user, starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 1, 31), planned_income: 5000
    )
    previous.allocations.create!(category: category, planned_amount: 1500)

    patch copy_previous_finance_budget_path("2026-02")

    assert_redirected_to finance_budget_path("2026-02")
    budget = PersonalFinance::BudgetPeriod.find_by!(user: user, starts_on: Date.new(2026, 2, 1))
    assert_equal 5000, budget.planned_income.to_f
    assert_equal 1, budget.allocations.count
    assert_equal 1500, budget.allocations.first.planned_amount.to_f
    assert_equal category.id, budget.allocations.first.category_id
  end

  test "copy_previous redirects with alert when no previous budget exists" do
    patch copy_previous_finance_budget_path("2026-01")

    assert_redirected_to finance_budget_path("2026-01")
    follow_redirect!
    assert_response :success
  end

  test "show offers copy button for empty month with previous budget" do
    user = User.dashboard_owner
    PersonalFinance::BudgetPeriod.create!(
      user: user, starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 1, 31), planned_income: 1000
    )

    get finance_budget_path("2026-02")

    assert_response :success
    assert_select "button", I18n.t("budgets.copy_previous", default: "Önceki Aydan Kopyala")
  end

  test "applies a template to an empty monthly budget" do
    user = User.dashboard_owner
    category = PersonalFinance::Category.create!(user: user, name: "Food", kind: "expense", color: "#3B82F6")
    template = PersonalFinance::BudgetTemplate.create!(user: user, name: "Food plan", allocation_data: [{"category_name" => "Food", "planned_amount" => "900"}])

    post apply_template_finance_budget_path("2026-04"), params: {template_id: template.id}

    budget = PersonalFinance::BudgetPeriod.find_by!(user: user, starts_on: Date.new(2026, 4, 1))
    assert_redirected_to finance_budget_path("2026-04")
    assert_equal 900, budget.allocations.find_by!(category: category).planned_amount.to_f
  end

  test "saves the current budget as a custom template" do
    user = User.dashboard_owner
    category = PersonalFinance::Category.create!(user: user, name: "Food", kind: "expense", color: "#3B82F6")
    budget = PersonalFinance::BudgetPeriod.create!(user: user, starts_on: Date.new(2026, 5, 1), ends_on: Date.new(2026, 5, 31))
    budget.allocations.create!(category: category, planned_amount: 900)

    post save_as_template_finance_budget_path("2026-05"), params: {name: "Ev planı"}

    assert_equal "900.0", PersonalFinance::BudgetTemplate.find_by!(user: user, name: "Ev planı").allocation_data.first["planned_amount"]
  end
end
