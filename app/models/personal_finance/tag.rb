module PersonalFinance
  class Tag < ApplicationRecord
    self.table_name = "finance_tags"

    belongs_to :user, class_name: "::User"
    has_many :transaction_tags, class_name: "PersonalFinance::TransactionTag", dependent: :destroy
    has_many :transactions, through: :transaction_tags, source: :financial_transaction

    before_validation :normalize_name

    validates :name, presence: true, length: {maximum: 50}, uniqueness: {scope: :user_id, case_sensitive: false}

    private

    def normalize_name
      self.name = name.to_s.strip.gsub(/\s+/, " ")
    end
  end
end
