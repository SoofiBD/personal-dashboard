require "test_helper"

class PersonalFinance::PaymentReminderNotificationGeneratorTest < ActiveSupport::TestCase
  test "creates deduplicated reminders for due subscriptions, debts, and review candidates" do
    user = User.create!(name: "Reminder user", currency: "TRY", time_zone: "Europe/Istanbul")
    subscription = PersonalFinance::Subscription.create!(user: user, name: "Streaming", amount: 200, billing_interval: "monthly", renewal_on: Date.new(2026, 3, 4), active: true)
    debt = PersonalFinance::Debt.create!(user: user, name: "Loan", total_amount: 1000, remaining_amount: 500, monthly_payment: 100, remaining_installments: 5, next_payment_on: Date.new(2026, 3, 6), active: true)
    review = PersonalFinance::Subscription.create!(user: user, name: "Unused", amount: 20, billing_interval: "monthly", renewal_on: Date.new(2026, 4, 1), last_used_on: 3.months.ago.to_date, active: true)

    2.times { PersonalFinance::PaymentReminderNotificationGenerator.call(today: Date.new(2026, 3, 1)) }

    assert_equal 1, user.finance_notifications.where(kind: "subscription_renewal_#{subscription.id}_2026-03-04").count
    assert_equal 1, user.finance_notifications.where(kind: "debt_payment_#{debt.id}_2026-03-06").count
    assert_equal 1, user.finance_notifications.where(kind: "subscription_review_#{review.id}_2026-03-01").count
  end

  test "skips inactive and payments outside the notification windows" do
    user = User.create!(name: "Inactive user", currency: "TRY", time_zone: "Europe/Istanbul")
    PersonalFinance::Subscription.create!(user: user, name: "Inactive", amount: 100, billing_interval: "monthly", renewal_on: Date.new(2026, 3, 4), active: false)
    PersonalFinance::Debt.create!(user: user, name: "Later", total_amount: 100, remaining_amount: 100, monthly_payment: 10, remaining_installments: 10, next_payment_on: Date.new(2026, 3, 7), active: true)

    PersonalFinance::PaymentReminderNotificationGenerator.call(today: Date.new(2026, 3, 1))

    assert_empty user.finance_notifications
  end
end
