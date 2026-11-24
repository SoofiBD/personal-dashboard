module PersonalFinance
  class RecurringRule < ApplicationRecord
    self.table_name = "finance_recurring_rules"

    belongs_to :user, class_name: "::User"
    belongs_to :account, class_name: "PersonalFinance::Account", foreign_key: :financial_account_id
    belongs_to :category, class_name: "PersonalFinance::Category", optional: true
    has_many :transactions, class_name: "PersonalFinance::Transaction", dependent: :restrict_with_error

    enum :kind, {income: "income", expense: "expense", transfer: "transfer"}, validate: true
    enum :recurrence_interval, {weekly: "weekly", biweekly: "biweekly", monthly: "monthly", yearly: "yearly"}, validate: true

    scope :active, -> { where(is_paused: false, stopped_at: nil) }

    validates :amount, numericality: {greater_than: 0, less_than_or_equal_to: 99_999_999}
    validates :starts_on, :last_generated_on, presence: true
    validates :note, length: {maximum: 500}
    validates :recurrence_count, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
    validate :end_date_is_not_before_start
    validate :owned_account
    validate :matching_category_kind

    def next_occurrence_on
      advance_date(last_generated_on)
    end

    def can_generate_on?(date)
      stopped_at.blank? && !is_paused? && (recurrence_end_date.blank? || date <= recurrence_end_date) &&
        (recurrence_count.blank? || generated_count < recurrence_count)
    end

    def stopped?
      stopped_at.present?
    end

    def advance_date(date)
      case recurrence_interval
      when "weekly" then date + 1.week
      when "biweekly" then date + 2.weeks
      when "monthly" then date.advance(months: 1)
      when "yearly" then date.advance(years: 1)
      end
    end

    private

    def end_date_is_not_before_start
      return unless starts_on && recurrence_end_date && recurrence_end_date < starts_on
      errors.add(:recurrence_end_date, "must be on or after the start date")
    end

    def owned_account
      errors.add(:account, "is invalid") if account && account.user_id != user_id
    end

    def matching_category_kind
      return unless category
      errors.add(:category, "is invalid") if category.user_id != user_id || category.kind != kind
    end
  end
end
