module PersonalGym
  class Workout < ApplicationRecord
    self.table_name = "gym_workouts"

    belongs_to :user, class_name: "::User"
    belongs_to :routine, class_name: "PersonalGym::Routine", optional: true
    has_many :sets, class_name: "PersonalGym::WorkoutSet", foreign_key: :workout_id, dependent: :destroy, inverse_of: :workout
    has_many :exercises, through: :sets, class_name: "PersonalGym::Exercise"

    enum :status, {active: "active", finished: "finished", discarded: "discarded"}, validate: true

    validates :started_at, presence: true
    validates :notes, length: {maximum: 500}, allow_blank: true
    validate :single_active_session

    scope :recent_first, -> { order(started_at: :desc) }
    scope :with_details, -> { includes(sets: :exercise) }

    def self.active_for(user)
      user.gym_workouts.active.order(started_at: :desc).first
    end

    private

    def single_active_session
      return unless active?
      return unless user
      return if user.gym_workouts.active.where.not(id: id).none?

      errors.add(:status, "an active workout already exists")
    end
  end
end
