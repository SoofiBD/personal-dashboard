class ApplicationController < ActionController::Base
  before_action :set_locale

  private

  def set_locale
    locale = params[:locale] || session[:locale] || cookies[:locale] || I18n.default_locale
    locale = I18n.available_locales.map(&:to_s).include?(locale.to_s) ? locale.to_sym : I18n.default_locale
    session[:locale] = locale
    cookies[:locale] = { value: locale.to_s, expires: 1.year.from_now }
    I18n.locale = locale
  end
end

