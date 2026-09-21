module PersonalGym
  class DashboardController < ApplicationController
    def show
      @active_workout = owned(Workout).active.with_details.order(started_at: :desc).first
      @routines = owned(Routine).ordered
      @recent_workouts = owned(Workout).finished.recent_first.with_details.limit(5)
      @week_volume = Gym::WorkoutQueries.weekly_volume(current_user).sum { |row| row[:tonnage] }
      @weekly_streak = Gym::WorkoutQueries.weekly_streak(current_user)
      @month_sessions = owned(Workout).finished.where(started_at: Date.current.all_month).count
      @top_exercises = Gym::WorkoutQueries.volume_by_exercise(current_user).first(5)
    end
  end
end
