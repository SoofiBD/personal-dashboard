module PersonalGym
  class DashboardController < ApplicationController
    def show
      @active_workout = owned(Workout).active.with_details.order(started_at: :desc).first
      @routines = owned(Routine).includes(:days).ordered
      @recent_workouts = owned(Workout).finished.recent_first.with_details.limit(5)
      @week_volume = Gym::WorkoutQueries.weekly_volume(current_user).sum { |row| row[:tonnage] }
      @weekly_streak = Gym::WorkoutQueries.weekly_streak(current_user)
      @month_sessions = owned(Workout).finished.where(started_at: Date.current.all_month).count
      @top_exercises = Gym::WorkoutQueries.volume_by_exercise(current_user).first(5)
      @body_metrics = current_user.gym_body_metrics.recent_first.limit(5)
      @latest_weight = @body_metrics.first
      @weight_change = weight_change
      @week_range = Date.current.beginning_of_week..Date.current.end_of_week
      @scheduled_workouts = current_user.gym_schedule_entries.includes(routine_day: :routine).during(@week_range)
      @routine_days = @routines.flat_map(&:days).sort_by { |day| [day.routine.name, day.position] }
      @muscle_volume = Gym::WorkoutQueries.muscle_volume(current_user).first(8)
      @muscle_readiness = Gym::WorkoutQueries.muscle_readiness(current_user).first(8)
    end

    private

    def weight_change
      return nil if @body_metrics.size < 2

      (@body_metrics.first.weight_kg - @body_metrics.last.weight_kg).round(1)
    end
  end
end
