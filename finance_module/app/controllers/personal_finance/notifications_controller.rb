module PersonalFinance
  class NotificationsController < ApplicationController
    def index
      @notifications = owned(Notification).recent_first
      @unread_count = @notifications.unread.count
    end

    def mark_all_read
      owned(Notification).unread.update_all(read_at: Time.current)
      redirect_to finance_notifications_path, notice: "Tüm bildirimler okundu olarak işaretlendi."
    end
  end
end
