class AiSettingsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_sensitive_caching

  def show
    @user = current_user
    @jan = Ai::JanClient.new
    @health = @jan.health
  rescue Ai::JanClient::Error => e
    @health = {connected: false, models: [], error: e.message}
  end

  def health
    jan = Ai::JanClient.new
    result = jan.health.merge(endpoint: jan.base_url)
    render json: result, status: (result[:connected] ? :ok : :service_unavailable)
  rescue Ai::JanClient::Error => e
    render json: {connected: false, models: [], error: e.message}, status: :service_unavailable
  end

  def update
    model = params.dig(:user, :ai_model).to_s
    jan = Ai::JanClient.new
    available_models = jan.models
    unless model.blank? || available_models.include?(model)
      @user = current_user
      @user.errors.add(:ai_model, "Jan tarafından sunulan modellerden biri olmalıdır.")
      @jan = jan
      @health = {connected: true, models: available_models}
      return render :show, status: :unprocessable_content
    end

    current_user.update!(ai_provider: "jan_local", ai_model: model.presence)
    redirect_to ai_settings_path, notice: "Yerel yapay zekâ tercihi kaydedildi."
  rescue Ai::JanClient::Error => e
    redirect_to ai_settings_path, alert: "Model seçimi doğrulanamadı: #{e.message}"
  end
end
