class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s.strip.to_sym
    if I18n.available_locales.include?(locale)
      session[:locale] = locale
      cookies[:locale] = {value: locale.to_s, expires: 1.year.from_now}
      current_user.update_column(:locale, locale.to_s) if current_user
      I18n.locale = locale
    end
    redirect_back(fallback_location: finance_root_path)
  end
end
