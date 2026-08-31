require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = ENV.fetch("DASHBOARD_AUTH_PASSWORD")

  setup do
    @owner = User.dashboard_owner
    @owner.update!(password: PASSWORD, password_confirmation: PASSWORD, onboarded_at: Time.current)
  end

  test "valid password creates an authenticated session" do
    post session_path, params: {password: PASSWORD}

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "login returns to the requested finance path" do
    get export_finance_data_path(format: :json)
    post session_path, params: {password: PASSWORD}

    assert_redirected_to export_finance_data_path(format: :json)
  end

  test "oversized return paths are not persisted in the cookie session" do
    get finance_transactions_path(search: "x" * 3000)
    post session_path, params: {password: PASSWORD}

    assert_redirected_to root_path
  end

  test "invalid password does not create an authenticated session" do
    post session_path, params: {password: "incorrect-password"}

    assert_response :unprocessable_content
    get finance_root_path
    assert_redirected_to new_session_path
  end

  test "logout invalidates the authenticated session" do
    post session_path, params: {password: PASSWORD}
    delete session_path
    get finance_root_path

    assert_redirected_to new_session_path
  end

  test "password rotation revokes the existing session" do
    post session_path, params: {password: PASSWORD}
    @owner.rotate_dashboard_password!("rotated-dashboard-password")
    get finance_root_path

    assert_redirected_to new_session_path
  end

  test "deleted session user is rejected" do
    orphaned_user = User.create!(name: "Temporary User", email: "temporary@example.test", currency: "TRY", time_zone: "Europe/Istanbul", role: "viewer", password: PASSWORD, password_confirmation: PASSWORD, onboarded_at: Time.current)
    post session_path, params: {identifier: orphaned_user.email, password: PASSWORD}
    orphaned_user.destroy!
    get finance_root_path

    assert_redirected_to new_session_path
  end

  test "mfa-enabled user must complete a second step before accessing finance data" do
    @owner.prepare_mfa!
    @owner.enable_mfa!(Totp.code_for(@owner.mfa_secret))

    post session_path, params: {password: PASSWORD}
    assert_redirected_to mfa_path

    get finance_root_path
    assert_redirected_to new_session_path

    post verify_mfa_path, params: {code: Totp.code_for(@owner.mfa_secret)}
    assert_redirected_to root_path
  end
end
