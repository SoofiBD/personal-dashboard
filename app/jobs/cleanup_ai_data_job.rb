# frozen_string_literal: true

class CleanupAiDataJob < ApplicationJob
  queue_as :default

  TERMINAL_ACTION_RETENTION = 90.days

  def perform
    AiAction.where(status: "pending").where("expires_at <= ?", Time.current).update_all(status: "expired", updated_at: Time.current)
    AiAction.where(status: %w[rejected executed failed expired]).where("updated_at < ?", TERMINAL_ACTION_RETENTION.ago).delete_all
    AiConversation.cleanup_old(days: 3).delete_all
    RateLimitCounter.where("expires_at < ?", 1.day.ago).delete_all
  end
end
