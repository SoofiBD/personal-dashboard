module PersonalFinance
  class TransactionImport < ApplicationRecord
    self.table_name = "finance_transaction_imports"

    belongs_to :user, class_name: "::User"
    belongs_to :account, class_name: "PersonalFinance::Account", foreign_key: :financial_account_id

    validates :source_csv, presence: true
    validate :owned_account

    def imported?
      imported_at.present?
    end

    private

    def owned_account
      errors.add(:account, "is invalid") if account && account.user_id != user_id
    end
  end
end
