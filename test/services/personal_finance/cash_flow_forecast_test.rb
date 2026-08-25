require "test_helper"

class PersonalFinance::CashFlowForecastTest < ActiveSupport::TestCase
  setup do
    @user = User.dashboard_owner
    @account = PersonalFinance::Account.create!(user: @user, name: "Main", kind: "bank", opening_balance: 1000)
    income_category = PersonalFinance::Category.create!(user: @user, name: "Salary", kind: "income", color: "#10B981")
    expense_category = PersonalFinance::Category.create!(user: @user, name: "Living", kind: "expense", color: "#EF4444")

    [1, 2, 3].each do |months_ago|
      PersonalFinance::Transaction.create!(user: @user, account: @account, category: income_category, kind: "income", amount: 300, occurred_on: months_ago.months.ago.to_date)
      PersonalFinance::Transaction.create!(user: @user, account: @account, category: expense_category, kind: "expense", amount: 120, occurred_on: months_ago.months.ago.to_date)
    end

    PersonalFinance::RecurringRule.create!(user: @user, account: @account, category: income_category, kind: "income", amount: 50, starts_on: Date.current.beginning_of_month, last_generated_on: Date.current, recurrence_interval: "monthly")
    PersonalFinance::RecurringRule.create!(user: @user, account: @account, category: expense_category, kind: "expense", amount: 20, starts_on: Date.current.beginning_of_month, last_generated_on: Date.current, recurrence_interval: "monthly")
    PersonalFinance::SavingsGoal.create!(user: @user, name: "Holiday", target_amount: 500, starting_amount: 0, monthly_contribution: 40, status: "active")
    PersonalFinance::PurchasePlan.create!(user: @user, name: "Laptop", price: 75, down_payment: 0, monthly_cost: 0, planned_on: Date.current.next_month.beginning_of_month)
  end

  test "projects balances with recurring rules, goals, and purchase plans" do
    forecast = PersonalFinance::CashFlowForecast.new(@user, months: 3)
    projection = forecast.projection

    assert_equal 3, projection.size
    assert_equal 300.0, forecast.baseline_income
    assert_equal 120.0, forecast.baseline_expenses
    assert_equal 50.0, projection.first[:recurring_income]
    assert_equal 20.0, projection.first[:recurring_expenses]
    assert_equal 40.0, projection.first[:goal_contributions]
    assert_equal 75.0, projection.first[:purchase_commitments]
    assert_equal 1635.0, projection.first[:balance]
  end
end
