module PersonalGym
  class Exercise < ApplicationRecord
    self.table_name = "gym_exercises"

    has_many :routine_exercises, class_name: "PersonalGym::RoutineExercise", foreign_key: :exercise_id, dependent: :restrict_with_error
    has_many :workout_sets, class_name: "PersonalGym::WorkoutSet", foreign_key: :exercise_id, dependent: :restrict_with_error

    enum :category, {strength: "strength", cardio: "cardio", timed: "timed"}, prefix: :category, validate: true
    enum :logging_mode, {reps: "reps", time: "time", cardio: "cardio"}, prefix: :mode, validate: true

    validates :name, presence: true, length: {maximum: 120}
    validates :slug, presence: true, uniqueness: {case_sensitive: false}, format: {with: /\A[a-z0-9-]+\z/}
    validates :muscle_group, length: {maximum: 60}, allow_blank: true
    validates :equipment, length: {maximum: 60}, allow_blank: true

    scope :search, ->(query) { where("gym_exercises.name ILIKE ?", "%#{sanitize_sql_like(query)}%") }
    scope :ordered, -> { order(:muscle_group, :name) }
  end
end
