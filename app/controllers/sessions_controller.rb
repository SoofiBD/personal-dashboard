class SessionsController < ApplicationController
  layout "authentication"
  before_action :prevent_sensitive_caching

  def new
    redirect_to finance_root_path if authenticated?
  end

  def create
    owner = User.dashboard_owner_record

    if owner&.authenticate(params[:password].to_s)
      destination = safe_return_to
      reset_session
      session[:user_id] = owner.id
      session[:authentication_version] = owner.authentication_version
      redirect_to destination, notice: "Giriş başarılı."
    else
      flash.now[:alert] = "Parola geçersiz veya dashboard erişimi henüz yapılandırılmamış."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Oturum kapatıldı."
  end

  private

  def safe_return_to
    destination = session.delete(:return_to).to_s
    return finance_root_path unless destination.start_with?("/") && !destination.start_with?("//")

    destination
  end
end
