module PersonalGym
  class RoutineDaysController < ApplicationController
    def create
      routine = owned(Routine).find(params[:routine_id])
      position = (routine.days.maximum(:position) || 0) + 1
      day = routine.days.new(name: day_params[:name].presence || "Gün #{position}", position: position)
      if day.save
        redirect_to edit_gym_routine_path(routine), notice: t("gym.saved", default: "Kaydedildi.")
      else
        redirect_to edit_gym_routine_path(routine), alert: day.errors.full_messages.to_sentence
      end
    end

    def destroy
      day = RoutineDay.joins(:routine).find(params[:id])
      routine = day.routine
      raise ActionController::RoutingError, "Not Found" unless routine.user_id == current_user.id

      day.destroy
      redirect_to edit_gym_routine_path(routine), notice: t("gym.deleted", default: "Silindi.")
    end

    private

    def day_params
      params.require(:gym_routine_day).permit(:name)
    end
  end
end
