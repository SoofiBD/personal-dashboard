module PersonalFinance
  class TransactionTag < ApplicationRecord
    self.table_name = "finance_transaction_tags"

    belongs_to :financial_transaction, class_name: "PersonalFinance::Transaction", foreign_key: :transaction_id
    belongs_to :tag, class_name: "PersonalFinance::Tag"

    validates :tag_id, uniqueness: {scope: :transaction_id}
  end
end
