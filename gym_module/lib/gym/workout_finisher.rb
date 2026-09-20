module Gym
  # Finishes a workout and produces an honest summary. Ported from openGym's
  # finish-workout.js essentials (AGPL-3.0).
  class WorkoutFinisher
    def initialize(workout)
      @workout = workout
    end

    def self.finish!(workout)
      new(workout).finish!
    end

    def finish!
      ActiveRecord::Base.transaction do
        @workout.update!(finished_at: Time.current, status: "finished")
      end
      summary
    end

    def summary
      @summary ||= begin
        sets = @workout.sets.includes(:exercise).ordered
        exercises = sets.map(&:exercise).uniq

        {
          duration_seconds: duration_seconds,
          tonnage: Gym::Effort.tonnage(sets),
          active_seconds: Gym::Effort.active_seconds(sets),
          completion: Gym::Effort.completion(sets),
          set_count: sets.size,
          done_count: sets.count(&:done?),
          best_sets: exercises.filter_map do |exercise|
            best = Gym::OneRm.best_set_of(sets.select { |set| set.exercise_id == exercise.id })
            next nil unless best

            {exercise: exercise, **best}
          end
        }
      end
    end

    private

    def duration_seconds
      return nil unless @workout.finished_at && @workout.started_at

      (@workout.finished_at - @workout.started_at).to_i
    end
  end
end
