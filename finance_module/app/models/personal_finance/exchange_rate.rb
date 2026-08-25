module PersonalFinance
  class ExchangeRate < ApplicationRecord
    self.table_name = "finance_exchange_rates"

    belongs_to :user, class_name: "::User"

    before_validation :normalize_currencies

    validates :base_currency, :quote_currency, presence: true, length: {is: 3}
    validates :rate, numericality: {greater_than: 0}
    validates :base_currency, uniqueness: {scope: %i[user_id quote_currency]}
    validate :different_currencies

    private

    def normalize_currencies
      self.base_currency = base_currency.to_s.upcase
      self.quote_currency = quote_currency.to_s.upcase
    end

    def different_currencies
      errors.add(:quote_currency, "must differ from base currency") if base_currency == quote_currency
    end
  end
end
