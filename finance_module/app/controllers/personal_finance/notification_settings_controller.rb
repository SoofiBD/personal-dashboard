module PersonalFinance
  class NotificationSettingsController < ApplicationController
    def update
      current_panel_user.update!(notification_params)
      redirect_to finance_notifications_path, notice: "Harcama limitleri güncellendi."
    rescue ActiveRecord::RecordInvalid
      redirect_to finance_notifications_path, alert: "Harcama limitleri güncellenemedi."
    end

    private

    def notification_params
      params.require(:user).permit(:daily_spending_limit, :weekly_spending_limit)
    end
  end
end
