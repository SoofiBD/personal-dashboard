module PersonalFinance
  class Transaction < ApplicationRecord
    self.table_name = "finance_transactions"

    belongs_to :user, class_name: "::User"
    belongs_to :account, class_name: "PersonalFinance::Account", foreign_key: :financial_account_id
    belongs_to :category, class_name: "PersonalFinance::Category", optional: true

    enum :kind, {income: "income", expense: "expense", transfer: "transfer"}, validate: true

    validates :amount, numericality: {greater_than: 0, less_than_or_equal_to: 99_999_999}
    validates :occurred_on, presence: true
    validates :note, length: {maximum: 500}
    validate :owned_account
    validate :matching_category_kind

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
  end
end
