class SessionsController < ApplicationController
  LOGIN_ATTEMPT_LIMIT = 10
  LOGIN_ATTEMPT_WINDOW = 15.minutes
  LOGIN_ATTEMPT_CACHE = ActiveSupport::Cache::MemoryStore.new

  layout "authentication"
  before_action :prevent_sensitive_caching

  def new
    redirect_to finance_root_path if authenticated?
  end

  def create
    if throttled_login?
      response.set_header("Retry-After", LOGIN_ATTEMPT_WINDOW.to_i.to_s)
      render plain: "Too many login attempts. Try again later.", status: :too_many_requests
      return
    end

    owner = User.dashboard_owner_record

    if owner&.authenticate(params[:password].to_s)
      LOGIN_ATTEMPT_CACHE.delete(login_attempt_cache_key)
      destination = safe_return_to
      reset_session
      session[:user_id] = owner.id
      session[:authentication_version] = owner.authentication_version
      redirect_to destination, notice: "Giriş başarılı."
    else
      record_login_attempt
      flash.now[:alert] = "Parola geçersiz veya dashboard erişimi henüz yapılandırılmamış."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Oturum kapatıldı."
  end

  private

  def login_attempt_cache_key
    "dashboard-login:#{request.remote_ip}"
  end

  def record_login_attempt
    LOGIN_ATTEMPT_CACHE.write(login_attempt_cache_key, LOGIN_ATTEMPT_CACHE.read(login_attempt_cache_key).to_i + 1, expires_in: LOGIN_ATTEMPT_WINDOW)
  end

  def throttled_login?
    LOGIN_ATTEMPT_CACHE.read(login_attempt_cache_key).to_i >= LOGIN_ATTEMPT_LIMIT
  end

  def safe_return_to
    destination = session.delete(:return_to).to_s
    return finance_root_path unless destination.start_with?("/") && !destination.start_with?("//")

    destination
  end
end
