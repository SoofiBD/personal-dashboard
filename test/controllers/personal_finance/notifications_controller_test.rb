require "test_helper"

class PersonalFinance::NotificationsControllerTest < PersonalFinance::IntegrationTest
  setup { User.dashboard_owner.update!(onboarded_at: Time.current) }

  test "shows notifications and saves spending limits" do
    get finance_notifications_path
    assert_response :success

    patch finance_notification_settings_path, params: {user: {daily_spending_limit: 300, weekly_spending_limit: 1500}}
    assert_equal 300, User.dashboard_owner.reload.daily_spending_limit.to_f
    assert_equal 1500, User.dashboard_owner.weekly_spending_limit.to_f
  end
end
