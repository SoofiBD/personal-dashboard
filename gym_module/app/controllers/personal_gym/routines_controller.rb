module PersonalGym
  class RoutinesController < ApplicationController
    before_action :set_routine, only: %i[edit update destroy]

    def index
      @routines = owned(Routine).includes(days: {routine_exercises: :exercise}).ordered
    end

    def new
      @routine = owned(Routine).new
    end

    def seed_templates
      count = PersonalGym::RoutineTemplates.install_for(current_user)
      redirect_to gym_routines_path, notice: t("gym.templates_seeded", count: count, default: "#{count} hazır plan eklendi.")
    end

    def create
      @routine = owned(Routine).new(routine_params)
      if @routine.save
        redirect_to gym_root_path, notice: t("gym.saved", default: "Kaydedildi.")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @routine.update(routine_params)
        redirect_to edit_gym_routine_path(@routine), notice: t("gym.saved", default: "Kaydedildi.")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @routine.destroy
      redirect_to gym_root_path, notice: t("gym.deleted", default: "Silindi.")
    end

    private

    def set_routine
      @routine = owned(Routine).find(params[:id])
    end

    def routine_params
      params.require(:gym_routine).permit(:name, :description)
    end
  end
end
