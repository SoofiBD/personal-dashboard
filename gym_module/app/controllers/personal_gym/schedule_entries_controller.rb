# frozen_string_literal: true

module PersonalGym
  class ScheduleEntriesController < ApplicationController
    def create
      entry = current_user.gym_schedule_entries.new(schedule_params)
      if entry.save
        redirect_to gym_root_path, notice: t("gym.schedule_saved", default: "Antrenman haftana eklendi.")
      else
        redirect_to gym_root_path, alert: entry.errors.full_messages.to_sentence
      end
    end

    def destroy
      current_user.gym_schedule_entries.find(params[:id]).destroy!
      redirect_to gym_root_path, notice: t("gym.schedule_deleted", default: "Planlı antrenman kaldırıldı.")
    end

    private

    def schedule_params
      params.require(:gym_schedule_entry).permit(:routine_day_id, :scheduled_on)
    end
  end
end
