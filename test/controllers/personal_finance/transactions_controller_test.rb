require "test_helper"
require "csv"

class PersonalFinance::TransactionsControllerTest < PersonalFinance::IntegrationTest
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
    @tag = PersonalFinance::Tag.create!(user: @user, name: "Vacation")
    @t1.tags << @tag
  end

  test "should get index with all transactions" do
    get finance_transactions_path
    assert_response :success
    assert_select ".transaction-category", text: /Weekly groceries buy/
    assert_select ".transaction-category", text: /Monthly payout salary/
  end

  test "paginates transaction results while preserving the requested page" do
    24.times do |index|
      PersonalFinance::Transaction.create!(user: @user, account: @account, category: @category_food, kind: :expense, amount: index + 1, occurred_on: Date.current, note: "Paged transaction #{index}")
    end

    get finance_transactions_path(page: 2)

    assert_response :success
    assert_select ".finance-item-row", count: 1
    assert_select ".pagination a", text: "1"
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

  test "should filter by tag" do
    get finance_transactions_path(tag_id: @tag.id)

    assert_response :success
    assert_select ".transaction-tag", text: "Vacation"
    assert_select ".transaction-category", text: /Monthly payout salary/, count: 0
  end

  test "creates transaction with comma-separated tags" do
    post finance_transactions_path, params: {transaction: {financial_account_id: @account.id, category_id: @category_food.id, kind: "expense", amount: 80, occurred_on: Date.current, tag_names: "Vacation, Work"}}

    assert_redirected_to finance_transactions_path
    assert_equal %w[Vacation Work], PersonalFinance::Transaction.find_by!(amount: 80).tags.order(:name).pluck(:name)
  end

  test "exports filtered transactions as an Excel-compatible CSV" do
    from = (Date.current - 7.days).to_s
    to = Date.current.to_s

    get finance_transactions_path(format: :csv, category_id: [@category_food.id], from: from, to: to)

    assert_response :success
    assert_match "text/csv", response.content_type
    assert_equal "\uFEFF", response.body[0]
    expected_month = @t1.occurred_on.strftime("%Y-%m")
    assert_includes response.headers["Content-Disposition"], "transactions_#{expected_month}_#{expected_month}.csv"

    rows = CSV.parse(response.body.delete_prefix("\uFEFF"))
    assert_equal %w[date type amount category account tags note], rows.first
    assert_equal 2, rows.size
    assert_equal [(Date.current - 5.days).iso8601, "expense", "50.0", "Food", "Card", "Vacation", "Weekly groceries buy"], rows.second
  end

  test "exports every filtered transaction regardless of the requested page" do
    24.times do |index|
      PersonalFinance::Transaction.create!(user: @user, account: @account, category: @category_food, kind: :expense, amount: index + 1, occurred_on: Date.current, note: "Export transaction #{index}")
    end

    get finance_transactions_path(format: :csv, page: 2)

    assert_response :success
    assert_equal 27, CSV.parse(response.body.delete_prefix("\uFEFF")).size
  end
end
