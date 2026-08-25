class ApplicationController < ActionController::Base
  before_action :set_locale
  helper_method :current_user, :authenticated?

  def current_user
    return @current_user if defined?(@current_user)

    candidate = User.find_by(id: session[:user_id])
    @current_user = candidate if candidate &&
      session[:authentication_version].present? &&
      session[:authentication_version].to_i == candidate.authentication_version

    if session[:user_id].present? && @current_user.nil?
      session.delete(:user_id)
      session.delete(:authentication_version)
    end
    @current_user
  end

  def authenticated?
    current_user.present?
  end

  private

  def require_authentication
    return if authenticated?

    if request.get? && request.fullpath.bytesize <= 2048
      session[:return_to] = request.fullpath
    else
      session.delete(:return_to)
    end
    redirect_to new_session_path, alert: "Devam etmek için giriş yapın."
  end

  def prevent_sensitive_caching
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
  end

  def set_locale
    locale = params[:locale] || session[:locale] || cookies[:locale] || I18n.default_locale
    locale = I18n.available_locales.map(&:to_s).include?(locale.to_s) ? locale.to_sym : I18n.default_locale
    session[:locale] = locale
    cookies[:locale] = {value: locale.to_s, expires: 1.year.from_now}
    I18n.locale = locale
  end
end
