require "test_helper"
require "minitest/mock"

class PersonalFinance::UpdateExchangeRatesJobTest < ActiveJob::TestCase
  test "delegates the daily update to the exchange-rate updater" do
    called = false
    updater = Object.new
    updater.define_singleton_method(:call) { called = true }

    PersonalFinance::ExchangeRateUpdater.stub :new, -> { updater } do
      PersonalFinance::UpdateExchangeRatesJob.perform_now
    end

    assert called
  end
end
