require "test_helper"

class PersonalFinance::AccountTest < ActiveSupport::TestCase
  test "loads balance histories for multiple accounts with two transaction queries" do
    user = User.create!(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")
    income = PersonalFinance::Category.create!(user: user, name: "Income", kind: :income, color: "#10B981")
    expense = PersonalFinance::Category.create!(user: user, name: "Expense", kind: :expense, color: "#EF4444")
    first_month = Date.current.beginning_of_month - 5.months
    cash = PersonalFinance::Account.create!(user: user, name: "Cash", kind: :cash, opening_balance: 100)
    bank = PersonalFinance::Account.create!(user: user, name: "Bank", kind: :bank, opening_balance: 200)
    PersonalFinance::Transaction.create!(user: user, account: cash, category: income, kind: :income, amount: 50, occurred_on: first_month - 1.day)
    PersonalFinance::Transaction.create!(user: user, account: cash, category: expense, kind: :expense, amount: 20, occurred_on: Date.current)
    PersonalFinance::Transaction.create!(user: user, account: bank, category: income, kind: :income, amount: 25, occurred_on: Date.current)

    transaction_queries = []
    callback = ->(_name, _start, _finish, _id, payload) { transaction_queries << payload[:sql] if payload[:sql].include?("finance_transactions") }
    histories = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { PersonalFinance::Account.balance_histories([cash, bank]) }

    assert_equal 2, transaction_queries.count
    assert_equal 130.0, histories[cash].last[:balance]
    assert_equal 225.0, histories[bank].last[:balance]
  end
end
