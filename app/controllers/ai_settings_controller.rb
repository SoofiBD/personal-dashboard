# frozen_string_literal: true

class AiSettingsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_sensitive_caching

  def show
    @user = current_user
    @jan = Ai::JanClient.new
    @jan_health = @jan.health
  rescue Ai::JanClient::Error => e
    @jan_health = { connected: false, models: [], error: e.message }
  end

  def health
    jan = Ai::JanClient.new
    result = jan.health.merge(endpoint: jan.base_url)
    render json: result, status: (result[:connected] ? :ok : :service_unavailable)
  rescue Ai::JanClient::Error => e
    render json: { connected: false, models: [], error: e.message }, status: :service_unavailable
  end

  def update
    provider = params.dig(:user, :ai_provider).to_s
    model = params.dig(:user, :ai_model).to_s

    unless %w[jan_local gemini].include?(provider)
      @user = current_user
      @user.errors.add(:ai_provider, 'Geçersiz sağlayıcı')
      @jan = Ai::JanClient.new
      @jan_health = { connected: true, models: [] }
      return render :show, status: :unprocessable_content
    end

    if provider == 'jan_local'
      jan = Ai::JanClient.new
      available_models = jan.models
      unless model.blank? || available_models.include?(model)
        @user = current_user
        @user.errors.add(:ai_model, 'Jan tarafından sunulan modellerden biri olmalıdır.')
        @jan = jan
        @jan_health = { connected: true, models: available_models }
        return render :show, status: :unprocessable_content
      end
    else
      unless model.present?
        @user = current_user
        @user.errors.add(:ai_model, 'Gemini model adı gereklidir.')
        @jan = Ai::JanClient.new
        @jan_health = { connected: true, models: [] }
        return render :show, status: :unprocessable_content
      end
    end

    current_user.update!(ai_provider: provider, ai_model: model.presence)
    redirect_to ai_settings_path, notice: 'Yapay zekâ tercihi kaydedildi.'
  rescue Ai::JanClient::Error => e
    redirect_to ai_settings_path, alert: "Model doğrulanamadı: #{e.message}"
  end
end
