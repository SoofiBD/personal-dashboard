# frozen_string_literal: true

class AiSettingsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_sensitive_caching

  def show
    @user = current_user
    @gemini_status = AiProviderStatus.check(model: AiAssistantService.model_for(@user))
  end

  def update
    model = params.dig(:user, :ai_model).to_s

    unless model.present?
      @user = current_user
      @user.errors.add(:ai_model, "Gemini model adı gereklidir.")
      @gemini_status = AiProviderStatus.check(model: AiAssistantService.model_for(@user))
      return render :show, status: :unprocessable_content
    end

    current_user.update!(ai_model: model)
    redirect_to ai_settings_path, notice: "Yapay zekâ tercihi kaydedildi."
  end
end
