class RateLimitCounter < ApplicationRecord
  validates :key, presence: true

  def self.with_attempt(key:, limit:, window:)
    transaction(requires_new: true) do
      counter = create_or_find_by!(key: key)
      counter.lock!

      return :throttled if counter.active? && counter.attempts >= limit

      outcome = yield
      if outcome == :valid
        counter.destroy!
      else
        counter.update!(
          attempts: counter.active? ? counter.attempts + 1 : 1,
          expires_at: Time.current + window
        )
      end

      outcome
    end
  end

  def active?
    expires_at&.future?
  end
end
