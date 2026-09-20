# frozen_string_literal: true

class AiChatsController < ApplicationController
  before_action :require_authentication

  def create
    message = params[:message].to_s.strip
    return render json: { error: 'Message required' }, status: :unprocessable_content if message.blank?

    service = AiAssistantService.new(user: current_user)
    response = service.ask(message)
    render json: { response: response }
  rescue AiAssistantService::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end

  def destroy
    current_user.ai_conversations.delete_all
    render json: { success: true }
  end
end
