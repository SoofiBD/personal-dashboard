require "test_helper"

class RecoveryCodesControllerTest < ActionDispatch::IntegrationTest
  OLD_PASSWORD = ENV.fetch("DASHBOARD_AUTH_PASSWORD")
  NEW_PASSWORD = "new-recovery-password-123"

  setup do
    @user = User.dashboard_owner
    @user.update!(password: OLD_PASSWORD, password_confirmation: OLD_PASSWORD)
    RateLimitCounter.delete_all
  end

  test "code is shown once, stored as a digest, and replaces the previous code" do
    post session_path, params: {password: OLD_PASSWORD}
    post profile_recovery_code_path

    assert_response :success
    code = response.body[/<code id="recovery-code">([^<]+)<\/code>/, 1]
    assert code.present?
    assert_equal Digest::SHA256.hexdigest(code), @user.reload.recovery_code_digest
    assert_equal "no-store", response.headers["Cache-Control"]

    get profile_path
    assert_response :success
    assert_select "#recovery-code", count: 0

    post profile_recovery_code_path
    assert_response :success
    assert_not_equal Digest::SHA256.hexdigest(code), @user.reload.recovery_code_digest
  end

  test "valid code resets password, revokes sessions, and cannot be reused" do
    post session_path, params: {password: OLD_PASSWORD}
    post profile_recovery_code_path
    code = response.body[/<code id="recovery-code">([^<]+)<\/code>/, 1]
    old_version = @user.reload.authentication_version
    delete session_path

    get password_recovery_path
    assert_response :success
    assert_select 'input[name="recovery_code"]'
    assert_select 'input[name="user[password]"]'
    assert_select 'input[name="user[password_confirmation]"]'

    post recover_password_path, params: {recovery_code: code, user: {password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD}}

    assert_redirected_to new_session_path
    assert @user.reload.authenticate(NEW_PASSWORD)
    assert_nil @user.recovery_code_digest
    assert_equal old_version + 1, @user.authentication_version

    post recover_password_path, params: {recovery_code: code, user: {password: OLD_PASSWORD, password_confirmation: OLD_PASSWORD}}
    assert_response :unprocessable_content
    assert @user.reload.authenticate(NEW_PASSWORD)
  end

  test "invalid password leaves code usable and guesses are rate limited" do
    post session_path, params: {password: OLD_PASSWORD}
    post profile_recovery_code_path
    code = response.body[/<code id="recovery-code">([^<]+)<\/code>/, 1]
    delete session_path

    post recover_password_path, params: {recovery_code: code, user: {password: "short", password_confirmation: "short"}}
    assert_response :unprocessable_content
    assert_equal Digest::SHA256.hexdigest(code), @user.reload.recovery_code_digest

    PasswordsController::RECOVERY_ATTEMPT_LIMIT.times do
      post recover_password_path, params: {recovery_code: "wrong-code", user: {password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD}}, headers: {"REMOTE_ADDR" => "192.0.2.2"}
      assert_response :unprocessable_content
    end
    post recover_password_path, params: {recovery_code: code, user: {password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD}}, headers: {"REMOTE_ADDR" => "192.0.2.2"}
    assert_response :too_many_requests
    assert_equal PasswordsController::RECOVERY_ATTEMPT_WINDOW.to_i.to_s, response.headers["Retry-After"]
  end

  test "unauthenticated visitor cannot create a code" do
    post profile_recovery_code_path
    assert_redirected_to new_session_path
    assert_nil @user.reload.recovery_code_digest
  end
end
