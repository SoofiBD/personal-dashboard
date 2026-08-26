require "test_helper"

class TotpTest < ActiveSupport::TestCase
  test "creates six digit codes and accepts the current time window" do
    secret = Totp.generate_secret
    code = Totp.code_for(secret, at: Time.utc(2026, 1, 1, 12, 0, 0))

    assert_match(/\A\d{6}\z/, code)
    assert Totp.valid?(secret, code, at: Time.utc(2026, 1, 1, 12, 0, 15))
    assert_not Totp.valid?(secret, code, at: Time.utc(2026, 1, 1, 12, 2, 0))
  end
end
