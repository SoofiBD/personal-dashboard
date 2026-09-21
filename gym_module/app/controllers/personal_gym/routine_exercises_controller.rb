module PersonalGym
  class RoutineExercisesController < ApplicationController
    def create
      day = RoutineDay.joins(:routine).find(params[:routine_id] || params[:routine_day_id])
      routine = day.routine
      raise ActionController::RoutingError, "Not Found" unless routine.user_id == current_user.id

      plan = day.routine_exercises.new(plan_params)
      plan.position = (day.routine_exercises.maximum(:position) || 0) + 1
      if plan.save
        redirect_to edit_gym_routine_path(routine), notice: t("gym.saved", default: "Kaydedildi.")
      else
        redirect_to edit_gym_routine_path(routine), alert: plan.errors.full_messages.to_sentence
      end
    end

    def update
      plan = RoutineExercise.joins(routine_day: :routine).find(params[:id])
      raise ActionController::RoutingError, "Not Found" unless plan.routine_day.routine.user_id == current_user.id

      if plan.update(plan_params)
        redirect_to edit_gym_routine_path(plan.routine_day.routine), notice: t("gym.saved", default: "Kaydedildi.")
      else
        redirect_to edit_gym_routine_path(plan.routine_day.routine), alert: plan.errors.full_messages.to_sentence
      end
    end

    def destroy
      plan = RoutineExercise.joins(routine_day: :routine).find(params[:id])
      routine = plan.routine_day.routine
      raise ActionController::RoutingError, "Not Found" unless routine.user_id == current_user.id

      plan.destroy
      redirect_to edit_gym_routine_path(routine), notice: t("gym.deleted", default: "Silindi.")
    end

    private

    def plan_params
      params.require(:gym_routine_exercise).permit(:exercise_id, :target_sets, :target_reps, :target_weight,
        :target_duration_seconds, :progression_policy, :warmup)
    end
  end
end
