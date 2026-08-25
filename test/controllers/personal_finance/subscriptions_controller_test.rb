require "test_helper"

class PersonalFinance::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup { User.dashboard_owner.update!(onboarded_at: Time.current) }

  test "creates a subscription" do
    post finance_subscriptions_path, params: {subscription: {name: "Netflix", amount: 250, billing_interval: "monthly", renewal_on: Date.current + 7.days, active: true}}

    assert_redirected_to finance_subscriptions_path
    assert_equal "Netflix", User.dashboard_owner.finance_subscriptions.last.name
  end
end
