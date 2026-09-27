# frozen_string_literal: true

class AiAction < ApplicationRecord
  ACTION_TYPES = %w[finance.create_expense finance.create_income finance.update_transaction finance.delete_transaction notes.create notes.update notes.delete learning.update_item learning.record_attempt learning.create_program gym.create_program gym.record_body_metric gym.schedule_workout memory.remember memory.forget documents.update_content].freeze
  STATUSES = %w[pending approved rejected executed failed expired].freeze
  MAX_REVIEW_PAYLOAD_BYTES = 64.kilobytes

  belongs_to :user

  validates :action_type, inclusion: {in: ACTION_TYPES}
  validates :status, inclusion: {in: STATUSES}
  validates :summary, presence: true, length: {maximum: 500}
  validate :payload_must_fit_review

  scope :pending_for, ->(user) { where(user: user, status: "pending").where("expires_at > ?", Time.current).order(created_at: :desc) }

  def self.propose!(user:, action_type:, payload:, summary:)
    create!(user: user, action_type: action_type, payload: payload, summary: summary, status: "pending", expires_at: 15.minutes.from_now)
  end

  def expired?
    expires_at <= Time.current
  end

  def expire_if_needed!
    update!(status: "expired") if status == "pending" && expired?
  end

  private

  def payload_must_fit_review
    errors.add(:payload, "is too large to review safely") if payload.to_json.bytesize > MAX_REVIEW_PAYLOAD_BYTES
  end
end
