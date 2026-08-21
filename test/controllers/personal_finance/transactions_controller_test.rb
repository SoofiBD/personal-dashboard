require "test_helper"

class PersonalFinance::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.first || User.create!(name: "Test User", currency: "TRY", time_zone: "Europe/Istanbul")
    @account = PersonalFinance::Account.create!(user: @user, name: "Card", kind: :bank, opening_balance: 1000)
    @category_food = PersonalFinance::Category.create!(user: @user, name: "Food", kind: :expense, color: "#EF4444")
    @category_salary = PersonalFinance::Category.create!(user: @user, name: "Salary", kind: :income, color: "#10B981")

    @t1 = PersonalFinance::Transaction.create!(
      user: @user,
      account: @account,
      category: @category_food,
      kind: :expense,
      amount: 50,
      occurred_on: Date.current - 5.days,
      note: "Weekly groceries buy"
    )

    @t2 = PersonalFinance::Transaction.create!(
      user: @user,
      account: @account,
      category: @category_salary,
      kind: :income,
      amount: 5000,
      occurred_on: Date.current,
      note: "Monthly payout salary"
    )
  end

  test "should get index with all transactions" do
    get finance_transactions_path
    assert_response :success
    assert_select ".transaction-category", text: /Weekly groceries buy/
    assert_select ".transaction-category", text: /Monthly payout salary/
  end

  test "should filter by search query" do
    get finance_transactions_path(q: "groceries")
    assert_response :success
    assert_select ".transaction-category", text: /Weekly groceries buy/
    assert_select ".transaction-category", text: /Monthly payout salary/, count: 0
  end

  test "should filter by transaction kind" do
    get finance_transactions_path(kind: "income")
    assert_response :success
    assert_select ".transaction-category", text: /Monthly payout salary/
    assert_select ".transaction-category", text: /Weekly groceries buy/, count: 0
  end

  test "should filter by account" do
    other_account = PersonalFinance::Account.create!(user: @user, name: "Cash", kind: :cash, opening_balance: 100)
    get finance_transactions_path(account_id: other_account.id)
    assert_response :success
    assert_select ".transaction-category", count: 0
  end

  test "should filter by date range" do
    get finance_transactions_path(from: (Date.current - 2.days).to_s, to: Date.current.to_s)
    assert_response :success
    assert_select ".transaction-category", text: /Monthly payout salary/
    assert_select ".transaction-category", text: /Weekly groceries buy/, count: 0
  end

  test "should filter by category" do
    get finance_transactions_path(category_id: [@category_food.id.to_s])
    assert_response :success
    assert_select ".transaction-category", text: /Weekly groceries buy/
    assert_select ".transaction-category", text: /Monthly payout salary/, count: 0
  end
end
