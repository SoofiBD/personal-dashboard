# frozen_string_literal: true

class AiConversation < ApplicationRecord
  belongs_to :user

  scope :recent_for, lambda { |user, limit: 10|
    where(user: user).order(created_at: :desc).limit(limit)
  }

  scope :cleanup_old, lambda { |days: 3|
    where("created_at < ?", days.days.ago)
  }
end
