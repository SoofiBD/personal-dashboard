require "test_helper"

class PersonalFinance::OnboardingControllerTest < PersonalFinance::IntegrationTest
  setup do
    # Clear any existing data so we test clean first-time user experience
    PersonalFinance::BudgetAllocation.delete_all
    PersonalFinance::BudgetPeriod.delete_all
    PersonalFinance::Transaction.delete_all
    PersonalFinance::Category.delete_all
    PersonalFinance::Account.delete_all
    PersonalFinance::SavingsGoal.delete_all
    PersonalFinance::PurchasePlan.delete_all
    User.delete_all
    sign_in_dashboard_owner
  end

  test "new user visiting finance root is redirected to onboarding" do
    get finance_root_path

    assert_redirected_to finance_onboarding_path
  end

  test "onboarding page renders 5-step wizard successfully" do
    get finance_onboarding_path

    assert_response :success
    assert_select "h1", I18n.t("onboarding.title")
    assert_select ".stepper-step", 5
    assert_select ".wizard-step", 5
  end

  test "completing full onboarding flow creates all records and marks user onboarded" do
    post finance_onboarding_path, params: {
      currency: "EUR",
      planned_income: "45000",
      accounts: [
        {name: "Cüzdan", kind: "cash", opening_balance: "750"},
        {name: "Banka", kind: "bank", opening_balance: "30000"}
      ],
      categories: [
        {name: "Market & Yemek", kind: "expense", color: "#10B981", icon: "shopping-cart", enabled: "1"},
        {name: "Ev & Faturalar", kind: "expense", color: "#3B82F6", icon: "home", enabled: "1"},
        {name: "Maaş", kind: "income", color: "#10B981", icon: "dollar-sign", enabled: "1"}
      ],
      allocations: {
        "Market & Yemek" => "10000",
        "Ev & Faturalar" => "15000"
      },
      savings_goal: {
        name: "Acil Fon",
        target_amount: "50000",
        starting_amount: "5000",
        monthly_contribution: "4000",
        target_date: (Date.current + 1.year).to_s
      }
    }

    assert_redirected_to finance_root_path
    user = User.dashboard_owner.reload

    assert user.onboarded?
    assert_equal "EUR", user.currency
    assert_equal 2, user.financial_accounts.count
    assert_operator user.finance_categories.count, :>=, 3

    current_budget = user.finance_budget_periods.find_by(starts_on: Date.current.beginning_of_month)
    assert_not_nil current_budget
    assert_equal 45000, current_budget.planned_income.to_i
    assert_equal 2, current_budget.allocations.count

    goal = user.finance_savings_goals.find_by(name: "Acil Fon")
    assert_not_nil goal
    assert_equal 50000, goal.target_amount.to_i

    # Once onboarded, visiting dashboard works directly
    get finance_root_path
    assert_response :success
  end

  test "completing onboarding with optional accounts and savings goal omitted (steps 2 and 5 skipped)" do
    post finance_onboarding_path, params: {
      currency: "TRY",
      planned_income: "60000",
      categories: [
        {name: "Market & Yemek", kind: "expense", color: "#10B981", icon: "shopping-cart", enabled: "1"}
      ],
      allocations: {
        "Market & Yemek" => "12000"
      },
      savings_goal: {
        name: "",
        target_amount: "0"
      }
    }

    assert_redirected_to finance_root_path
    user = User.dashboard_owner.reload

    assert user.onboarded?
    assert_equal 0, user.financial_accounts.count
    assert_equal 0, user.finance_savings_goals.count
  end

  test "skipping entire wizard seeds default categories and budget period" do
    post skip_finance_onboarding_path

    assert_redirected_to finance_root_path
    user = User.dashboard_owner.reload

    assert user.onboarded?
    assert_operator user.finance_categories.count, :>=, 9
    assert_not_nil user.finance_budget_periods.find_by(starts_on: Date.current.beginning_of_month)

    get finance_root_path
    assert_response :success
  end
end
