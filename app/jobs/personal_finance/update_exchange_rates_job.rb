module PersonalFinance
  class UpdateExchangeRatesJob < ApplicationJob
    queue_as :default

    def perform
      ExchangeRateUpdater.new.call
    end
  end
end
