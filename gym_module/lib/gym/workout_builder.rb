module Gym
  # Builds an active workout from a routine day. Ported from openGym's
  # session-start.js + workout-model.js essentials (AGPL-3.0).
  #
  # Warmups are derived from the plan's `warmup` column: a comma-separated
  # list of percentages of the working weight ("40,70"). An empty history
  # means targets are used as-is; otherwise the progression policy derives
  # today's prescription from the most recent finished session.
  class WorkoutBuilder
    def initialize(user, routine_day)
      @user = user
      @routine_day = routine_day
    end

    def self.start!(user, routine_day)
      new(user, routine_day).start!
    end

    # Free-form session: one exercise, N working sets, no plan attached.
    def self.start_free!(user, exercise:, sets: 3, weight: nil, reps: nil, duration_seconds: nil)
      ActiveRecord::Base.transaction do
        workout = PersonalGym::Workout.create!(user: user, started_at: Time.current, status: "active")
        sets.to_i.clamp(1, 20).times do |index|
          workout.sets.create!(
            exercise: exercise,
            position: index,
            kind: "working",
            weight: weight,
            reps: reps,
            duration_seconds: duration_seconds
          )
        end
        workout
      end
    end

    def start!
      workout = nil
      ActiveRecord::Base.transaction do
        workout = PersonalGym::Workout.create!(
          user: @user,
          routine: @routine_day.routine,
          started_at: Time.current,
          status: "active"
        )

        @routine_day.routine_exercises.includes(:exercise).ordered.each do |plan|
          build_planned_sets(workout, plan)
        end
      end
      workout
    end

    private

    def build_planned_sets(workout, plan)
      exercise = plan.exercise
      target = derived_target(plan, exercise)
      position = 0

      parse_warmups(plan).each do |percent|
        workout.sets.create!(
          exercise: exercise,
          position: position += 1,
          kind: "warmup",
          weight: warmup_weight(target, percent),
          reps: target[:reps],
          duration_seconds: target[:duration_seconds]
        )
      end

      plan.target_sets.times do
        workout.sets.create!(
          exercise: exercise,
          position: position += 1,
          kind: "working",
          weight: target[:weight],
          reps: target[:reps],
          duration_seconds: target[:duration_seconds]
        )
      end
    end

    def derived_target(plan, exercise)
      target = {
        weight: plan.target_weight,
        reps: plan.target_reps.present? ? Gym::RepRange.bottom(plan.target_reps) : nil,
        duration_seconds: plan.target_duration_seconds
      }

      return target if plan.progression_policy == "off"

      prescription = prescription_for(plan, exercise)
      return target unless prescription

      target[:weight] = prescription[:weight] if prescription[:weight]
      target[:reps] = prescription[:reps] if prescription[:reps]
      target[:duration_seconds] = prescription[:duration_seconds] if prescription[:duration_seconds]
      target
    end

    def prescription_for(plan, exercise)
      last = last_finished_workout(exercise)
      return nil unless last

      sets = last.sets.where(exercise_id: exercise.id).ordered
      return nil unless sets.any?

      progression = Progression.new(
        history_sets: sets,
        target_sets: plan.target_sets,
        target_reps: plan.target_reps,
        target_duration_seconds: plan.target_duration_seconds
      )
      progression.next_target(plan.progression_policy)
    end

    def last_finished_workout(exercise)
      @user.gym_workouts
        .finished
        .joins(:sets)
        .where(gym_workout_sets: {exercise_id: exercise.id})
        .order(started_at: :desc)
        .first
    end

    def parse_warmups(plan)
      plan.warmup.to_s.split(",").filter_map { |part| Integer(part.strip, exception: false) }.select { |p| p.positive? && p < 100 }
    end

    def warmup_weight(target, percent)
      base = target[:weight].to_f
      return nil unless base.positive?

      (base * percent / 100.0).round(1)
    end
  end
end
