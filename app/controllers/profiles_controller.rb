class ProfilesController < ApplicationController
  before_action :require_authentication
  before_action :prevent_sensitive_caching

  def show
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      session[:locale] = @user.locale
      I18n.locale = @user.locale
      redirect_to profile_path, notice: I18n.t("backend.profiles.updated")
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :currency, :time_zone, :locale, :theme_preference)
  end
end
