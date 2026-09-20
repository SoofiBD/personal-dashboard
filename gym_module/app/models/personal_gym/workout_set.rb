module PersonalGym
  class WorkoutSet < ApplicationRecord
    self.table_name = "gym_workout_sets"

    belongs_to :workout, class_name: "PersonalGym::Workout", inverse_of: :sets
    belongs_to :exercise, class_name: "PersonalGym::Exercise"

    enum :kind, {warmup: "warmup", working: "working", failure: "failure"}, validate: true

    validates :position, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates :weight, numericality: {greater_than: 0, less_than_or_equal_to: 99_999}, allow_nil: true
    validates :reps, numericality: {only_integer: true, greater_than: 0, less_than_or_equal_to: 999}, allow_nil: true
    validates :duration_seconds, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
    validates :distance_km, numericality: {greater_than: 0}, allow_nil: true
    validate :owned_workout

    scope :ordered, -> { order(:position, :id) }
    scope :working, -> { where(kind: "working") }

    private

    def owned_workout
      return unless workout

      errors.add(:workout, "is invalid") if workout.user_id && workout.discarded?
    end
  end
end
