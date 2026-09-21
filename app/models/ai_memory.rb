# frozen_string_literal: true

class AiMemory < ApplicationRecord
  belongs_to :user

  validates :key, uniqueness: {scope: %i[user_id category]}

  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { order(updated_at: :desc) }
end
