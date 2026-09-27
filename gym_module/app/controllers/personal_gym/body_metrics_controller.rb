# frozen_string_literal: true

module PersonalGym
  class BodyMetricsController < ApplicationController
    def create
      metric = current_user.gym_body_metrics.new(metric_params)
      if metric.save
        redirect_to gym_root_path, notice: t("gym.metric_saved", default: "Ölçüm kaydedildi.")
      else
        redirect_to gym_root_path, alert: metric.errors.full_messages.to_sentence
      end
    end

    def destroy
      current_user.gym_body_metrics.find(params[:id]).destroy!
      redirect_to gym_root_path, notice: t("gym.metric_deleted", default: "Ölçüm silindi.")
    end

    private

    def metric_params
      params.require(:gym_body_metric).permit(:recorded_on, :weight_kg, :note)
    end
  end
end
