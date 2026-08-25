require "test_helper"

class PersonalFinance::SpendingNotificationGeneratorTest < ActiveSupport::TestCase
  test "creates one daily notification when the configured limit is exceeded" do
    user = User.dashboard_owner
    user.update!(daily_spending_limit: 100)
    account = PersonalFinance::Account.create!(user: user, name: "Cash", kind: "cash", opening_balance: 0)
    transaction = PersonalFinance::Transaction.create!(user: user, account: account, kind: "expense", amount: 120, occurred_on: Date.current)

    PersonalFinance::SpendingNotificationGenerator.call(transaction)
    PersonalFinance::SpendingNotificationGenerator.call(transaction)

    assert_equal 1, user.finance_notifications.where(kind: "daily_limit_#{Date.current}").count
  end
end
