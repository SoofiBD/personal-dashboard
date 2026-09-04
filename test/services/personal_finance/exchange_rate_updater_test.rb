require "test_helper"

class PersonalFinance::ExchangeRateUpdaterTest < ActiveSupport::TestCase
  test "updates only account currencies needed for each user's display currency" do
    user = User.create!(name: "Rate user", currency: "TRY", time_zone: "Europe/Istanbul")
    PersonalFinance::Account.create!(user: user, name: "USD account", kind: "bank", opening_balance: 0, currency: "USD")
    PersonalFinance::Account.create!(user: user, name: "EUR account", kind: "bank", opening_balance: 0, currency: "EUR")
    requested_uris = []
    fetcher = lambda do |uri|
      requested_uris << uri.to_s
      base = URI.decode_www_form(uri.query).to_h.fetch("base")
      [{"base" => base, "quote" => "TRY", "rate" => ((base == "USD") ? 32.5 : 35.2)}].to_json
    end

    PersonalFinance::ExchangeRateUpdater.new(fetcher: fetcher).call

    assert_equal 2, requested_uris.size
    assert_includes requested_uris, "https://api.frankfurter.dev/v2/rates?base=USD&quotes=TRY"
    assert_equal 32.5, PersonalFinance::ExchangeRate.find_by!(user: user, base_currency: "USD", quote_currency: "TRY").rate.to_f
    assert_equal 35.2, PersonalFinance::ExchangeRate.find_by!(user: user, base_currency: "EUR", quote_currency: "TRY").rate.to_f
  end

  test "reuses a fetched pair and preserves an existing record on an invalid response" do
    first = User.create!(name: "First", currency: "TRY", time_zone: "Europe/Istanbul")
    second = User.create!(name: "Second", currency: "TRY", time_zone: "Europe/Istanbul")
    [first, second].each { |user| PersonalFinance::Account.create!(user: user, name: "USD #{user.id}", kind: "bank", opening_balance: 0, currency: "USD") }
    existing = PersonalFinance::ExchangeRate.create!(user: first, base_currency: "USD", quote_currency: "TRY", rate: 1)
    calls = 0

    fetcher = lambda do |_uri|
      calls += 1
      "not json"
    end
    PersonalFinance::ExchangeRateUpdater.new(fetcher: fetcher).call

    assert_equal 1, calls
    assert_equal 1, existing.reload.rate.to_i
  end
end
