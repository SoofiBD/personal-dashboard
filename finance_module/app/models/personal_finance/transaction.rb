module PersonalFinance
  class Transaction < ApplicationRecord
    self.table_name = "finance_transactions"

    belongs_to :user, class_name: "::User"
    belongs_to :account, class_name: "PersonalFinance::Account", foreign_key: :financial_account_id
    belongs_to :category, class_name: "PersonalFinance::Category", optional: true
    belongs_to :recurring_rule, class_name: "PersonalFinance::RecurringRule", optional: true
    has_many :transaction_tags, class_name: "PersonalFinance::TransactionTag", foreign_key: :transaction_id, dependent: :destroy
    has_many :tags, through: :transaction_tags, class_name: "PersonalFinance::Tag"

    enum :kind, {income: "income", expense: "expense", transfer: "transfer"}, validate: true

    attr_accessor :recurrence_interval, :recurrence_end_date, :recurrence_count, :savings_goal_id

    validates :amount, numericality: {greater_than: 0, less_than_or_equal_to: 99_999_999}
    validates :occurred_on, presence: true
    validates :note, length: {maximum: 500}
    validate :owned_account
    validate :matching_category_kind
    validate :goal_contribution_requires_savings_transfer

    scope :during, ->(range) { where(occurred_on: range) }
    scope :search_notes, ->(query) { where("finance_transactions.note ILIKE ?", "%#{query}%") }

    private

    def owned_account
      errors.add(:account, "is invalid") if account && account.user_id != user_id
    end

    def matching_category_kind
      return unless category
      errors.add(:category, "is invalid") if category.user_id != user_id || category.kind != kind
    end

    def goal_contribution_requires_savings_transfer
      return if savings_goal_id.blank?
      errors.add(:base, "Goal contributions require a transfer to a savings account") unless transfer? && account&.savings?
    end
  end
end
