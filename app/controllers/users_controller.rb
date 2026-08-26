class UsersController < ApplicationController
  before_action :require_authentication
  before_action :require_owner
  before_action :prevent_sensitive_caching
  before_action :set_user, only: %i[edit update]

  def index
    @users = User.order(:role, :name)
  end

  def new
    @user = User.new(currency: current_user.currency, time_zone: current_user.time_zone, locale: current_user.locale, role: "viewer")
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "Kullanıcı oluşturuldu."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @user == current_user && user_params[:role].present? && user_params[:role] != "owner"
      @user.errors.add(:role, "sahip rolü kendi hesabınızdan kaldırılamaz")
      render :edit, status: :unprocessable_content
    elsif @user.update(user_params)
      redirect_to users_path, notice: "Kullanıcı güncellendi."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def require_owner
    return if current_user&.owner?

    redirect_to finance_root_path, alert: "Bu işlem yalnızca hesap sahibine açıktır."
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = params.require(:user).permit(:name, :email, :role, :currency, :time_zone, :locale, :password, :password_confirmation)
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
    permitted
  end
end
