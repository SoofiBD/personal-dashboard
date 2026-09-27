# frozen_string_literal: true

module PersonalGym
  class BodyMetric < ApplicationRecord
    self.table_name = "gym_body_metrics"

    belongs_to :user, class_name: "::User"

    validates :recorded_on, presence: true
    validates :weight_kg, numericality: {greater_than: 20, less_than_or_equal_to: 500}
    validates :note, length: {maximum: 1_000}

    scope :recent_first, -> { order(recorded_on: :desc) }
  end
end
