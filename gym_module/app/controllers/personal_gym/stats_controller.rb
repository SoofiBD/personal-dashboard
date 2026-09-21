module PersonalGym
  class StatsController < ApplicationController
    def show
      @weekly_volume = Gym::WorkoutQueries.weekly_volume(current_user)
      @top_exercises = Gym::WorkoutQueries.volume_by_exercise(current_user)
      @streak = Gym::WorkoutQueries.weekly_streak(current_user)
      @totals = totals
    end

    private

    def totals
      sets = WorkoutSet.joins(:workout)
        .where(gym_workouts: {user_id: current_user.id, status: "finished"})
      {
        sessions: owned(Workout).finished.count,
        tonnage: Gym::Effort.tonnage(sets),
        sets_done: sets.where(done: true).count
      }
    end
  end
end
