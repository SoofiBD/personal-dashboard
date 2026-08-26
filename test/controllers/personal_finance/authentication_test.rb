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

  test "viewer cannot mutate financial data" do
    password = "viewer-dashboard-password"
    viewer = User.create!(name: "Viewer", email: "viewer@example.test", role: "viewer", currency: "TRY", time_zone: "Europe/Istanbul", password: password, password_confirmation: password, onboarded_at: Time.current)
    delete session_path
    post session_path, params: {identifier: viewer.email, password: password}

    post finance_accounts_path, params: {account: {name: "Read only", kind: "cash", opening_balance: "0", currency: "TRY"}}
    assert_redirected_to finance_root_path
    assert_equal "Bu kullanıcı finansal verilerde değişiklik yapamaz.", flash[:alert]
  end
end
