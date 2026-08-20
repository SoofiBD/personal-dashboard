module PersonalFinance
  class Account < ApplicationRecord
    self.table_name = "financial_accounts"

    belongs_to :user, class_name: "::User"
    has_many :transactions, class_name: "PersonalFinance::Transaction", foreign_key: :financial_account_id, dependent: :restrict_with_error

    enum :kind, {cash: "cash", bank: "bank", card: "card", savings: "savings"}, validate: true

    validates :name, presence: true, length: {maximum: 80}
    validates :opening_balance, numericality: true

    def current_balance
      opening_balance + transactions.sum("CASE WHEN kind = 'income' THEN amount WHEN kind = 'expense' THEN -amount ELSE 0 END")
    end
  end
end
