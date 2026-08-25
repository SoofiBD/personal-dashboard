require "test_helper"

class PersonalFinance::CurrencyConverterTest < ActiveSupport::TestCase
  test "converts an account balance with a user-managed exchange rate" do
    user = User.dashboard_owner
    PersonalFinance::ExchangeRate.create!(user: user, base_currency: "USD", quote_currency: "TRY", rate: 32.5)

    assert_equal 3250.0, PersonalFinance::CurrencyConverter.new(user).convert(100, "USD").to_f
  end
end
