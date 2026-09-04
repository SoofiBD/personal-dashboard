class SessionsController < ApplicationController
  LOGIN_ATTEMPT_LIMIT = 10
  LOGIN_ATTEMPT_WINDOW = 15.minutes

  layout "authentication"
  before_action :prevent_sensitive_caching

  def new
    redirect_to root_path if authenticated?
  end

  def create
    user = nil
    result = RateLimitCounter.with_attempt(
      key: login_attempt_cache_key,
      limit: LOGIN_ATTEMPT_LIMIT,
      window: LOGIN_ATTEMPT_WINDOW
    ) do
      user = login_user
      user&.authenticate(params[:password].to_s) ? :valid : :invalid
    end

    if result == :throttled
      response.set_header("Retry-After", LOGIN_ATTEMPT_WINDOW.to_i.to_s)
      render plain: "Too many login attempts. Try again later.", status: :too_many_requests
      return
    end

    if result == :valid
      destination = safe_return_to
      reset_session
      if user.mfa_enabled?
        session[:pending_mfa_user_id] = user.id
        session[:pending_mfa_authentication_version] = user.authentication_version
        session[:pending_mfa_return_to] = destination
        redirect_to mfa_path, notice: I18n.t("backend.sessions.mfa_prompt")
      else
        establish_authenticated_session(user)
        redirect_to destination, notice: I18n.t("backend.sessions.signed_in")
      end
    else
      record_login_attempt
      flash.now[:alert] = I18n.t("backend.sessions.invalid_credentials")
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: I18n.t("backend.sessions.signed_out")
  end

  private

  def establish_authenticated_session(user)
    session[:user_id] = user.id
    session[:authentication_version] = user.authentication_version
  end

  def login_attempt_cache_key
    "dashboard-login:#{request.remote_ip}"
  end

  def login_user
    identifier = params[:identifier].to_s.strip.downcase
    return User.dashboard_owner_record if identifier.blank?

    user = User.where("lower(email) = ? OR lower(name) = ?", identifier, identifier).order(:id).first
    user || ((User.count == 1) ? User.dashboard_owner_record : nil)
  end

  def safe_return_to
    destination = session.delete(:return_to).to_s
    return root_path unless destination.start_with?("/") && !destination.start_with?("//")

    destination
  end
end
