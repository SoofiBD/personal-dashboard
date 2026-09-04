module PersonalFinance
  class PaymentReminderNotificationsJob < ApplicationJob
    queue_as :default

    def perform
      PaymentReminderNotificationGenerator.call
    end
  end
end
