require "test_helper"

class RateLimitCounterTest < ActiveSupport::TestCase
  setup { RateLimitCounter.delete_all }

  test "shares a persisted counter and resets it after a valid attempt" do
    key = "test-rate-limit"

    2.times do
      assert_equal :invalid, RateLimitCounter.with_attempt(key: key, limit: 2, window: 15.minutes) { :invalid }
    end
    assert_equal :throttled, RateLimitCounter.with_attempt(key: key, limit: 2, window: 15.minutes) { :valid }

    RateLimitCounter.delete_all
    assert_equal :valid, RateLimitCounter.with_attempt(key: key, limit: 2, window: 15.minutes) { :valid }
    assert_nil RateLimitCounter.find_by(key: key)
  end
end
