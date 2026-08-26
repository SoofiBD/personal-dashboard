class MfaController < ApplicationController
  layout "authentication"
  before_action :prevent_sensitive_caching

  def show
    if authenticated?
      @setup_user = current_user
      @setup_user.prepare_mfa! unless @setup_user.mfa_enabled? || @setup_user.mfa_pending_setup?
    else
      @challenge_user = pending_mfa_user
      redirect_to new_session_path, alert: "Önce parolanızla giriş yapın." unless @challenge_user
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
      redirect_to new_session_path, alert: "Önce giriş yapın."
      return
    end

    current_user.disable_mfa!
    redirect_to profile_path, notice: "İki adımlı doğrulama kapatıldı."
  end

  private

  def pending_mfa_user
    user = User.find_by(id: session[:pending_mfa_user_id])
    return unless user && session[:pending_mfa_authentication_version].to_i == user.authentication_version && user.mfa_enabled?

    user
  end

  def verify_login_challenge
    user = pending_mfa_user
    unless user&.then { |candidate| Totp.valid?(candidate.mfa_secret, params[:code]) }
      flash.now[:alert] = "Doğrulama kodu geçersiz veya süresi dolmuş."
      @challenge_user = user
      render :show, status: :unprocessable_content
      return
    end

    destination = session.delete(:pending_mfa_return_to) || finance_root_path
    reset_session
    session[:user_id] = user.id
    session[:authentication_version] = user.authentication_version
    redirect_to destination, notice: "Giriş başarılı."
  end

  def verify_setup
    if current_user.enable_mfa!(params[:code])
      redirect_to profile_path, notice: "İki adımlı doğrulama etkinleştirildi."
    else
      flash.now[:alert] = "Doğrulama kodu geçersiz."
      @setup_user = current_user
      render :show, status: :unprocessable_content
    end
  end
end
