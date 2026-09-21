module PersonalGym
  class WorkoutsController < ApplicationController
    before_action :set_workout, only: %i[show finish destroy]

    def index
      @workouts = owned(Workout).finished.recent_first.with_details.limit(30)
    end

    def show
    end

    def create
      if params[:routine_day_id].present?
        day = RoutineDay.joins(:routine).find(params[:routine_day_id])
        raise ActionController::RoutingError, "Not Found" unless day.routine.user_id == current_user.id

        workout = Gym::WorkoutBuilder.start!(current_user, day)
        redirect_to gym_workout_path(workout), notice: t("gym.started", default: "Antrenman başladı.")
      elsif params[:exercise_id].present?
        exercise = Exercise.find(params[:exercise_id])
        workout = Gym::WorkoutBuilder.start_free!(current_user, exercise: exercise,
          sets: params[:sets], reps: params[:reps])
        redirect_to gym_workout_path(workout), notice: t("gym.started", default: "Antrenman başladı.")
      else
        redirect_to gym_root_path, alert: t("gym.start_requires_plan", default: "Bir gün veya egzersiz seçin.")
      end
    rescue ActiveRecord::RecordInvalid => error
      redirect_to gym_root_path, alert: error.record.errors.full_messages.to_sentence
    end

    def finish
      return redirect_to gym_workout_path(@workout) unless @workout.active?

      Gym::WorkoutFinisher.finish!(@workout)
      redirect_to gym_workout_path(@workout), notice: t("gym.finished", default: "Antrenman tamamlandı.")
    end

    def destroy
      @workout.update!(status: "discarded", finished_at: @workout.finished_at || Time.current) if @workout.active?
      redirect_to gym_root_path, notice: t("gym.discarded", default: "Antrenman iptal edildi.")
    end

    private

    def set_workout
      @workout = owned(Workout).with_details.find(params[:id])
    end
  end
end
