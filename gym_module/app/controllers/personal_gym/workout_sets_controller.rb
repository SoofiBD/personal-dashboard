module PersonalGym
  class WorkoutSetsController < ApplicationController
    before_action :set_workout

    def create
      exercise = Exercise.find(set_params[:exercise_id])
      position = (@workout.sets.where(exercise_id: exercise.id).maximum(:position) || 0) + 1
      set = @workout.sets.new(set_params.merge(position: position, kind: "working"))
      if set.save
        redirect_to gym_workout_path(@workout), notice: t("gym.saved", default: "Kaydedildi.")
      else
        redirect_to gym_workout_path(@workout), alert: set.errors.full_messages.to_sentence
      end
    end

    def update
      set = @workout.sets.find(params[:id])
      if set.update(update_params)
        redirect_to gym_workout_path(@workout)
      else
        redirect_to gym_workout_path(@workout), alert: set.errors.full_messages.to_sentence
      end
    end

    def destroy
      set = @workout.sets.find(params[:id])
      set.destroy
      redirect_to gym_workout_path(@workout), notice: t("gym.deleted", default: "Silindi.")
    end

    private

    def set_workout
      @workout = owned(Workout).find(params[:workout_id])
      redirect_to gym_workout_path(@workout) unless @workout.active?
    end

    def set_params
      params.require(:gym_workout_set).permit(:exercise_id, :weight, :reps, :duration_seconds, :distance_km, :kind)
    end

    def update_params
      permitted = params.require(:gym_workout_set).permit(:weight, :reps, :duration_seconds, :distance_km, :done, :kind)
      permitted[:done] = permitted[:done] == "1" if permitted.key?(:done)
      permitted
    end
  end
end
