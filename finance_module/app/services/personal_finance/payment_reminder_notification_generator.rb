module PersonalFinance
  class PaymentReminderNotificationGenerator
    SUBSCRIPTION_LEAD_DAYS = 3
    DEBT_LEAD_DAYS = 5

    def self.call(today: Date.current)
      new(today: today).call
    end

    def initialize(today:)
      @today = today
    end

    def call
      create_subscription_renewal_notifications
      create_debt_payment_notifications
      create_subscription_review_notifications
    end

    private

    def create_subscription_renewal_notifications
      Subscription.active.where(renewal_on: @today + SUBSCRIPTION_LEAD_DAYS).find_each do |subscription|
        create_once(subscription.user, "subscription_renewal_#{subscription.id}_#{subscription.renewal_on}", "Abonelik yenilemesi yaklaşıyor", "#{subscription.name} aboneliğiniz #{subscription.renewal_on.strftime("%d.%m.%Y")} tarihinde #{subscription.amount.to_d.to_s("F")} tutarında yenilenecek.")
      end
    end

    def create_debt_payment_notifications
      Debt.where(active: true, next_payment_on: @today + DEBT_LEAD_DAYS).find_each do |debt|
        create_once(debt.user, "debt_payment_#{debt.id}_#{debt.next_payment_on}", "Borç taksiti yaklaşıyor", "#{debt.name} için #{debt.next_payment_on.strftime("%d.%m.%Y")} tarihinde #{debt.monthly_payment.to_d.to_s("F")} tutarında ödeme planlanıyor.")
      end
    end

    def create_subscription_review_notifications
      Subscription.active.find_each do |subscription|
        next unless subscription.potentially_cancellable?

        create_once(subscription.user, "subscription_review_#{subscription.id}_#{@today.beginning_of_month}", "Aboneliğinizi gözden geçirin", "#{subscription.name} aboneliğiniz iptal edilmeye uygun olabilir; kullanım ve maliyeti gözden geçirin.")
      end
    end

    def create_once(user, kind, title, body)
      Notification.find_or_create_by!(user: user, kind: kind) do |notification|
        notification.title = title
        notification.body = body
      end
    end
  end
end
