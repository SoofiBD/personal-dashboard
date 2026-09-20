class PasswordsController < ApplicationController
  RESET_ATTEMPT_LIMIT = 3
  RESET_ATTEMPT_WINDOW = 60.minutes
  TOKEN_EXPIRY = 2.hours

  layout "authentication"
  before_action :prevent_sensitive_caching
  before_action :require_no_authentication, only: %i[new create edit update]
  before_action :set_user_by_token, only: %i[edit update]

  def new
  end

  def create
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email)

    result = RateLimitCounter.with_attempt(
      key: "password_reset:#{request.remote_ip}:#{email}",
      limit: RESET_ATTEMPT_LIMIT,
      window: RESET_ATTEMPT_WINDOW
    ) do
      :valid
    end

    if result == :throttled
      audit_security_event("password_reset_throttled", email: email)
      response.set_header("Retry-After", RESET_ATTEMPT_WINDOW.to_i.to_s)
      render plain: "Too many password reset attempts. Try again later.", status: :too_many_requests
      return
    end

    if user&.email.present?
      user.generate_password_reset_token!
      # In production, send email with reset link
      # For now, log the token for testing
      Rails.logger.info("Password reset token for #{user.email}: #{user.password_reset_token}")
      audit_security_event("password_reset_requested", user_id: user.id)
    else
      audit_security_event("password_reset_requested_unknown_email", email: email)
    end

    redirect_to confirm_password_path, notice: I18n.t("backend.passwords.reset_sent")
  end

  def confirm
  end

  def edit
  end

  def update
    if @user.password_reset_token_expired?
      audit_security_event("password_reset_token_expired", user_id: @user.id)
      redirect_to new_password_path, alert: I18n.t("backend.passwords.token_expired")
      return
    end

    if params[:user][:password].blank? || params[:user][:password_confirmation].blank?
      @user.errors.add(:password, I18n.t("backend.passwords.blank"))
      render :edit, status: :unprocessable_content
      return
    end

    if params[:user][:password] != params[:user][:password_confirmation]
      @user.errors.add(:password_confirmation, I18n.t("backend.passwords.mismatch"))
      render :edit, status: :unprocessable_content
      return
    end

    if @user.update(password: params[:user][:password], password_confirmation: params[:user][:password_confirmation])
      @user.clear_password_reset_token!
      audit_security_event("password_reset_completed", user_id: @user.id)
      reset_session
      redirect_to new_session_path, notice: I18n.t("backend.passwords.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def require_no_authentication
    redirect_to root_path if authenticated?
  end

  def set_user_by_token
    token = params[:token].to_s
    @user = User.find_by(password_reset_token: token)

    unless @user
      audit_security_event("password_reset_invalid_token", token: token)
      redirect_to new_password_path, alert: I18n.t("backend.passwords.invalid_token")
    end
  end
end