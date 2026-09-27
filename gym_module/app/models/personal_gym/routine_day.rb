module PersonalGym
  class RoutineDay < ApplicationRecord
    self.table_name = "gym_routine_days"

    belongs_to :routine, class_name: "PersonalGym::Routine"
    has_many :routine_exercises, class_name: "PersonalGym::RoutineExercise", foreign_key: :routine_day_id, dependent: :destroy, inverse_of: :routine_day
    has_many :schedule_entries, class_name: "PersonalGym::ScheduleEntry", foreign_key: :routine_day_id, dependent: :destroy

    validates :name, presence: true, length: {maximum: 80}

    scope :ordered, -> { order(:position, :id) }
  end
end
