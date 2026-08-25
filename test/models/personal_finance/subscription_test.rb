require "test_helper"

class PersonalFinance::SubscriptionTest < ActiveSupport::TestCase
  test "normalizes monthly and yearly subscription costs" do
    user = User.dashboard_owner
    yearly = PersonalFinance::Subscription.new(user: user, name: "Gym", amount: 1200, billing_interval: "yearly")
    monthly = PersonalFinance::Subscription.new(user: user, name: "Music", amount: 100, billing_interval: "monthly")

    assert_equal 100, yearly.monthly_cost.to_f
    assert_equal 1200, monthly.yearly_cost.to_f
  end
end
