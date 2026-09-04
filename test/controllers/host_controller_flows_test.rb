require "test_helper"

class HostControllerFlowsTest < ActionDispatch::IntegrationTest
  PASSWORD = ENV.fetch("DASHBOARD_AUTH_PASSWORD")

  setup do
    @owner = User.dashboard_owner
    @owner.update!(password: PASSWORD, password_confirmation: PASSWORD, onboarded_at: Time.current)
  end

  test "profiles require authentication and persist valid preferences" do
    get profile_path
    assert_redirected_to new_session_path

    sign_in(@owner)
    patch profile_path, params: {user: {name: "Updated Owner", email: @owner.email, currency: "USD", time_zone: "Europe/Istanbul", locale: "en", theme_preference: "dark"}}

    assert_redirected_to profile_path
    assert_equal "USD", @owner.reload.currency
    assert_equal "en", @owner.locale
  end

  test "owners manage users while viewers are redirected" do
    sign_in(@owner)
    assert_difference("User.count", 1) do
      post users_path, params: {user: {name: "Editor", email: "editor-controller@example.test", currency: "TRY", time_zone: "Europe/Istanbul", locale: "tr", password: PASSWORD, password_confirmation: PASSWORD, role: "editor"}}
    end
    assert_redirected_to users_path

    viewer = User.create!(name: "Viewer", email: "viewer-controller@example.test", role: "viewer", currency: "TRY", time_zone: "Europe/Istanbul", password: PASSWORD, password_confirmation: PASSWORD, onboarded_at: Time.current)
    delete session_path
    sign_in(viewer)
    get users_path
    assert_redirected_to finance_root_path
  end

  test "MFA setup validates codes and can be disabled" do
    sign_in(@owner)
    get mfa_path
    assert_response :success

    post verify_mfa_path, params: {code: "000000"}
    assert_response :unprocessable_content

    post verify_mfa_path, params: {code: Totp.code_for(@owner.reload.mfa_secret)}
    assert_redirected_to profile_path
    assert_predicate @owner.reload, :mfa_enabled?

    delete mfa_path
    assert_redirected_to profile_path
    assert_not_predicate @owner.reload, :mfa_enabled?
  end

  private

  def sign_in(user)
    post session_path, params: {identifier: user.email, password: PASSWORD}
    assert_response :redirect
  end
end
