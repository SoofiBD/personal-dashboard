module Gym
  # Read-only queries over the workout log: weekly volume, per-exercise
  # estimated 1RM series, streaks. Ported from the essentials of openGym's
  # history.js / onerm.js series helpers (AGPL-3.0).
  module WorkoutQueries
    WEEKS_SHOWN = 8
    SERIES_POINTS = 10

    module_function

    # One tonnage point per ISO week for the chart. Chronological.
    def weekly_volume(user, weeks: WEEKS_SHOWN)
      sets = PersonalGym::WorkoutSet
        .joins(:workout)
        .where(gym_workouts: {user_id: user.id, status: "finished"})

      first_week = weeks.weeks.ago.beginning_of_week.to_date
      totals = sets
        .where(gym_workouts: {started_at: first_week.beginning_of_day..})
        .group("DATE_TRUNC('week', gym_workouts.started_at)")
        .pluck(
          Arel.sql("DATE_TRUNC('week', gym_workouts.started_at)"),
          Arel.sql("COALESCE(SUM(gym_workout_sets.weight * gym_workout_sets.reps), 0)")
        )
        .to_h { |date, tonnage| [date.to_date, tonnage.to_f.round(1)] }

      weeks.times.map do |offset|
        week_start = first_week + offset.weeks
        {label: I18n.l(week_start, format: "%d %b"), tonnage: totals.fetch(week_start, 0.0)}
      end
    end

    # Chronological estimated-1RM series for one exercise: one point per
    # finished workout in which the exercise produced an estimate.
    def e1rm_series(user, exercise, limit: SERIES_POINTS)
      user.gym_workouts.finished
        .joins(:sets)
        .where(gym_workout_sets: {exercise_id: exercise.id})
        .order(started_at: :asc)
        .distinct
        .filter_map do |workout|
          best = Gym::OneRm.best_set_of(workout.sets.select { |set| set.exercise_id == exercise.id })
          next nil unless best

          {label: I18n.l(workout.started_at.to_date, format: :short), est: best[:estimate]}
        end.last(limit)
    end

    # Per-exercise tonnage over the last N days, descending. Feeds the
    # "most trained" list.
    def volume_by_exercise(user, since: 30.days.ago)
      PersonalGym::WorkoutSet
        .joins(:workout, :exercise)
        .where(gym_workouts: {user_id: user.id, status: "finished"})
        .where(gym_workouts: {started_at: since..})
        .where(kind: "working", done: true)
        .group("gym_exercises.name")
        .pluck("gym_exercises.name", Arel.sql("COALESCE(SUM(gym_workout_sets.weight * gym_workout_sets.reps), 0)"))
        .map { |name, tonnage| {name: name, tonnage: tonnage.to_f.round(1)} }
        .sort_by { |row| -row[:tonnage] }
    end

    # Consecutive finished-workout weeks ending this week (or last).
    def weekly_streak(user)
      weeks = user.gym_workouts.finished
        .where(started_at: 26.weeks.ago..)
        .pluck(:started_at)
        .map { |ts| ts.beginning_of_week.to_date }
        .uniq

      streak = 0
      cursor = Date.current.beginning_of_week
      cursor -= 1.week if weeks.exclude?(cursor)
      while weeks.include?(cursor)
        streak += 1
        cursor -= 1.week
      end
      streak
    end
  end
end
