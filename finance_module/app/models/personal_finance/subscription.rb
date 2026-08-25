module PersonalFinance
  class Subscription < ApplicationRecord
    self.table_name = "finance_subscriptions"

    belongs_to :user, class_name: "::User"
    belongs_to :recurring_rule, class_name: "PersonalFinance::RecurringRule", optional: true

    enum :billing_interval, {monthly: "monthly", yearly: "yearly"}, validate: true

    validates :name, presence: true, length: {maximum: 100}
    validates :amount, numericality: {greater_than: 0, less_than_or_equal_to: 99_999_999}
    validate :recurring_rule_belongs_to_user

    scope :active, -> { where(active: true) }

    def monthly_cost
      yearly? ? amount / 12 : amount
    end

    def yearly_cost
      monthly? ? amount * 12 : amount
    end

    def upcoming_renewal?
      renewal_on.present? && renewal_on.between?(Date.current, Date.current + 14.days)
    end

    def potentially_cancellable?
      (last_used_on.present? && last_used_on < 60.days.ago.to_date) || monthly_cost >= 1000
    end

    private

    def recurring_rule_belongs_to_user
      return unless recurring_rule
      errors.add(:recurring_rule, "is invalid") unless recurring_rule.user_id == user_id && recurring_rule.expense?
    end
  end
end
