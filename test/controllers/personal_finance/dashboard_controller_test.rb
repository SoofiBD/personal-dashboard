require "test_helper"

class PersonalFinance::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "dashboard is available without an authentication flow" do
    get finance_root_path

    assert_response :success
    assert_select "h1", I18n.t("dashboard.title")
    assert_equal 1, User.count
  end
end
