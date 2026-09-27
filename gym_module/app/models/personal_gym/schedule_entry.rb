# frozen_string_literal: true

module PersonalGym
  class ScheduleEntry < ApplicationRecord
    self.table_name = "gym_schedule_entries"

    belongs_to :user, class_name: "::User"
    belongs_to :routine_day, class_name: "PersonalGym::RoutineDay"

    validates :scheduled_on, presence: true
    validates :routine_day_id, uniqueness: {scope: [:user_id, :scheduled_on]}
    validate :routine_day_belongs_to_user

    scope :during, ->(range) { where(scheduled_on: range).order(:scheduled_on, :created_at) }

    private

    def routine_day_belongs_to_user
      return unless routine_day
      errors.add(:routine_day, "bu hesaba ait değil") unless routine_day.routine.user_id == user_id
    end
  end
end
