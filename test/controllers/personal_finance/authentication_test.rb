require "test_helper"

class PersonalFinance::AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.dashboard_owner
    @owner.update!(onboarded_at: Time.current)
  end

  test "anonymous dashboard and backup export are rejected" do
    get finance_root_path
    assert_redirected_to new_session_path

    get export_finance_data_path(format: :json)
    assert_redirected_to new_session_path
  end

  test "anonymous onboarding mutation is rejected without changing data" do
    assert_no_changes -> { @owner.reload.onboarded_at } do
      post skip_finance_onboarding_path
    end

    assert_redirected_to new_session_path
  end

  test "finance responses cannot be stored in browser caches" do
    password = ENV.fetch("DASHBOARD_AUTH_PASSWORD")
    @owner.update!(password: password, password_confirmation: password)
    post session_path, params: {password: password}
    get finance_root_path

    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
  end
end
