class MfaController < ApplicationController
  MFA_ATTEMPT_LIMIT = 5
  MFA_ATTEMPT_WINDOW = 15.minutes

  layout "authentication"
  before_action :prevent_sensitive_caching

  def show
    if authenticated?
      @setup_user = current_user
      @setup_user.prepare_mfa! unless @setup_user.mfa_enabled? || @setup_user.mfa_pending_setup?
    else
      @challenge_user = pending_mfa_user
      redirect_to new_session_path, alert: I18n.t("backend.mfa.password_first") unless @challenge_user
    end
  end

  def verify
    if authenticated?
      verify_setup
    else
      verify_login_challenge
    end
  end

  def destroy
    unless authenticated?
      redirect_to new_session_path, alert: I18n.t("backend.mfa.sign_in_first")
      return
    end

    current_user.disable_mfa!
    redirect_to profile_path, notice: I18n.t("backend.mfa.disabled")
  end

  private

  def pending_mfa_user
    user = User.find_by(id: session[:pending_mfa_user_id])
    return unless user && session[:pending_mfa_authentication_version].to_i == user.authentication_version && user.mfa_enabled?

    user
  end

  def verify_login_challenge
    user = pending_mfa_user
    result = user ? verify_mfa_attempt(user, params[:code]) : :invalid
    if result == :throttled
      reject_mfa_challenge
      return
    end

    if result == :invalid
      flash.now[:alert] = I18n.t("backend.mfa.invalid_or_expired")
      @challenge_user = user
      render :show, status: :unprocessable_content
      return
    end

    destination = session.delete(:pending_mfa_return_to) || root_path
    reset_session
    session[:user_id] = user.id
    session[:authentication_version] = user.authentication_version
    redirect_to destination, notice: I18n.t("backend.sessions.signed_in")
  end

  def verify_setup
    if current_user.enable_mfa!(params[:code])
      redirect_to profile_path, notice: I18n.t("backend.mfa.enabled")
    else
      flash.now[:alert] = I18n.t("backend.mfa.invalid")
      @setup_user = current_user
      render :show, status: :unprocessable_content
    end
  end

  def mfa_attempt_cache_key(user)
    "dashboard-mfa:#{user.id}"
  end

  def verify_mfa_attempt(user, code)
    RateLimitCounter.with_attempt(
      key: mfa_attempt_cache_key(user),
      limit: MFA_ATTEMPT_LIMIT,
      window: MFA_ATTEMPT_WINDOW
    ) do
      Totp.valid?(user.mfa_secret, code) ? :valid : :invalid
    end
  end

  def reject_mfa_challenge
    reset_session
    response.set_header("Retry-After", MFA_ATTEMPT_WINDOW.to_i.to_s)
    render plain: "Too many MFA attempts. Try again later.", status: :too_many_requests
  end
end
