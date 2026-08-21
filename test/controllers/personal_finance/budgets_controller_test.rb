require "test_helper"

class PersonalFinance::BudgetsControllerTest < ActionDispatch::IntegrationTest
  test "should get year budget view" do
    get finance_year_budget_path(year: 2026)
    assert_response :success
    assert_select "h1", "2026"
  end

  test "should return 404 for invalid year" do
    get finance_year_budget_path(year: 3000)
    assert_response :not_found
  end
end
