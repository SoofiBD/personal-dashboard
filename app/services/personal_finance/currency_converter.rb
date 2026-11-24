module PersonalFinance
  class CurrencyConverter
    def initialize(user)
      @user = user
    end

    def convert(amount, from_currency, to_currency = @user.currency)
      return amount.to_d if from_currency == to_currency
      rate = ExchangeRate.find_by(user: @user, base_currency: from_currency, quote_currency: to_currency)&.rate
      rate ? amount.to_d * rate : nil
    end
  end
end
