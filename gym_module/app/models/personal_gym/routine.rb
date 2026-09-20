module PersonalGym
  class Routine < ApplicationRecord
    self.table_name = "gym_routines"

    belongs_to :user, class_name: "::User"
    has_many :days, class_name: "PersonalGym::RoutineDay", foreign_key: :routine_id, dependent: :destroy, inverse_of: :routine
    has_many :workouts, class_name: "PersonalGym::Workout", foreign_key: :routine_id, dependent: :nullify

    validates :name, presence: true, length: {maximum: 120}
    validates :description, length: {maximum: 500}, allow_blank: true

    scope :ordered, -> { order(:name) }
  end
end
