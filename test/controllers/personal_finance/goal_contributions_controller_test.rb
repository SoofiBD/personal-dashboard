require "test_helper"

class PersonalFinance::GoalContributionsControllerTest < PersonalFinance::IntegrationTest
  setup do
    @user = User.dashboard_owner
    @savings_account = PersonalFinance::Account.create!(user: @user, name: "Savings", kind: "savings", opening_balance: 0)
    @goal = PersonalFinance::SavingsGoal.create!(user: @user, name: "Emergency Fund", target_amount: 2000, starting_amount: 0, monthly_contribution: 0, status: "active")
    @transfer = PersonalFinance::Transaction.create!(user: @user, account: @savings_account, kind: "transfer", amount: 300, occurred_on: Date.current)
  end

  test "links a goal contribution to a savings transfer and shows it in the goal detail" do
    post finance_savings_goal_goal_contributions_path(@goal), params: {goal_contribution: {transaction_id: @transfer.id, amount: 300, contributed_on: Date.current, note: "Monthly save"}}

    assert_redirected_to finance_savings_goal_path(@goal)
    contribution = @goal.contributions.last
    assert_equal @transfer.id, contribution.transaction_id

    get finance_savings_goal_path(@goal)
    assert_response :success
    assert_select ".goal-contribution-list", text: /Monthly save/
    assert_select ".recurring-badge", text: /Bağlantılı transfer/
  end

  test "rejects a goal link for a non-transfer transaction" do
    expense_account = PersonalFinance::Account.create!(user: @user, name: "Card", kind: "card", opening_balance: 0)
    category = PersonalFinance::Category.create!(user: @user, name: "Food", kind: "expense", color: "#3B82F6")

    post finance_transactions_path, params: {transaction: {financial_account_id: expense_account.id, category_id: category.id, kind: "expense", amount: 100, occurred_on: Date.current, savings_goal_id: @goal.id}}

    assert_response :unprocessable_entity
    assert_equal 0, @goal.contributions.count
  end

  test "creates a linked contribution when a savings transfer selects a goal" do
    post finance_transactions_path, params: {transaction: {financial_account_id: @savings_account.id, kind: "transfer", amount: 250, occurred_on: Date.current, savings_goal_id: @goal.id}}

    assert_redirected_to finance_transactions_path
    contribution = @goal.contributions.last
    assert_equal 250.0, contribution.amount.to_f
    assert_equal "transfer", contribution.linked_transaction.kind
  end

  test "linked transfers do not count as expenses" do
    PersonalFinance::BudgetPeriod.create!(user: @user, starts_on: Date.current.beginning_of_month, ends_on: Date.current.end_of_month, planned_income: 0)

    assert_equal 0, PersonalFinance::BudgetPeriod.last.actual_spending
  end
end
