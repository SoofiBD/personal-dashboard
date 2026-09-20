class SignupsController < ApplicationController
  layout "authentication"
  before_action :prevent_sensitive_caching
  before_action :ensure_signup_allowed, only: %i[new create]

  def new
    @user = User.new(
      currency: "TRY",
      time_zone: "Europe/Istanbul",
      locale: I18n.locale.to_s,
      role: "owner"
    )
  end

  def create
    @user = User.new(signup_params)
    @user.role = "owner"

    if @user.save
      audit_security_event("signup_succeeded", user_id: @user.id)
      redirect_to new_session_path, notice: I18n.t("backend.signups.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def ensure_signup_allowed
    return if User.count.zero?

    redirect_to new_session_path, alert: I18n.t("backend.signups.not_allowed")
  end

  def signup_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :currency, :time_zone, :locale)
  end
end