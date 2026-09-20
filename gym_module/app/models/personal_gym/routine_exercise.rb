module PersonalGym
  class RoutineExercise < ApplicationRecord
    self.table_name = "gym_routine_exercises"

    belongs_to :routine_day, class_name: "PersonalGym::RoutineDay", inverse_of: :routine_exercises
    belongs_to :exercise, class_name: "PersonalGym::Exercise"

    validates :target_sets, numericality: {only_integer: true, greater_than: 0, less_than_or_equal_to: 20}
    validates :target_reps, length: {maximum: 20}, allow_blank: true
    validates :target_duration_seconds, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
    validates :warmup, format: {with: /\A[\d,\s]*\z/}, allow_blank: true
    validate :reps_mode_requires_reps
    validate :time_mode_requires_duration
    validate :policy_supported_for_mode

    scope :ordered, -> { order(:position, :id) }

    private

    def reps_mode_requires_reps
      return unless exercise
      return unless exercise.mode_reps?
      return if Gym::RepRange.normalize(target_reps)

      errors.add(:target_reps, "is required for reps-mode exercises")
    end

    def time_mode_requires_duration
      return unless exercise
      return unless exercise.mode_time?
      return if target_duration_seconds.to_i.positive?

      errors.add(:target_duration_seconds, "is required for timed exercises")
    end

    def policy_supported_for_mode
      return unless exercise

      allowed = allowed_policies
      return if allowed.include?(progression_policy.to_s)

      errors.add(:progression_policy, "is not supported for this logging mode")
    end

    def allowed_policies
      if exercise.mode_cardio?
        %w[off]
      elsif exercise.mode_time?
        %w[off time]
      else
        Gym::Progression::POLICIES
      end
    end
  end
end
