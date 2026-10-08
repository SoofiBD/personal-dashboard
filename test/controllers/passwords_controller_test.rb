require "test_helper"
require "stringio"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.dashboard_owner
    @user.update!(email: "reset@example.test")
    @old_smtp = %w[SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD SMTP_FROM DASHBOARD_DOMAIN].to_h { |key| [key, ENV[key]] }
    ENV.update("SMTP_ADDRESS" => "smtp.example.test", "SMTP_USERNAME" => "mailer", "SMTP_PASSWORD" => "test-only-password", "SMTP_FROM" => "reset@example.test", "DASHBOARD_DOMAIN" => "dashboard.example.test")
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    @old_smtp.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    ActionMailer::Base.deliveries.clear
  end

  test "reset token is delivered by email and never logged or stored in plaintext" do
    logs = capture_rails_logs do
      post password_path, params: {email: @user.email}
    end

    assert_redirected_to confirm_password_path
    assert_equal 1, ActionMailer::Base.deliveries.size
    body = ActionMailer::Base.deliveries.last.body.decoded
    token = body[/token=([^\s&]+)/, 1]
    assert token.present?
    assert_equal Digest::SHA256.hexdigest(token), @user.reload.password_reset_digest
    assert_not_includes logs, token
  end

  test "invalid reset token is not copied to audit logs" do
    logs = capture_rails_logs do
      get edit_password_path(token: "attacker-supplied-secret")
    end

    assert_redirected_to new_password_path
    assert_not_includes logs, "attacker-supplied-secret"
  end

  test "missing mail configuration does not issue a reset token" do
    ENV.delete("SMTP_ADDRESS")

    post password_path, params: {email: @user.email}

    assert_redirected_to confirm_password_path
    assert_nil @user.reload.password_reset_digest
    assert_empty ActionMailer::Base.deliveries
  end

  test "password reset form submits credentials in the expected scope" do
    token = @user.generate_password_reset_token!
    previous_version = @user.authentication_version

    get edit_password_path(token: token)

    assert_response :success
    assert_select 'input[name="user[password]"]'
    assert_select 'input[name="user[password_confirmation]"]'

    patch password_path(token: token), params: {
      user: {password: "a-long-test-password", password_confirmation: "a-long-test-password"}
    }

    assert_redirected_to new_session_path
    assert @user.reload.authenticate("a-long-test-password")
    assert_nil @user.password_reset_digest
    assert_equal previous_version + 1, @user.authentication_version
  end

  test "malformed reset submission returns a validation error without using the token" do
    token = @user.generate_password_reset_token!

    patch password_path(token: token), params: {password: "a-long-test-password"}

    assert_response :unprocessable_content
    assert @user.reload.password_reset_digest.present?
  end

  private

  def capture_rails_logs
    output = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    yield
    output.string
  ensure
    Rails.logger = previous_logger
  end
end
