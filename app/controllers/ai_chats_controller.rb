# frozen_string_literal: true

class AiChatsController < ApplicationController
  MESSAGE_LIMIT = 6_000
  REQUEST_LIMIT = 30
  REQUEST_WINDOW = 10.minutes

  before_action :require_authentication
  before_action :prevent_sensitive_caching

  def show
    @conversations = current_user.ai_conversations.order(:created_at).last(40)
    @pending_actions = AiAction.pending_for(current_user)
  end

  def create
    message = params[:message].to_s.strip
    return render json: {error: "Message required"}, status: :unprocessable_content if message.blank?
    return render json: {error: "Mesaj en fazla #{MESSAGE_LIMIT} karakter olabilir."}, status: :unprocessable_content if message.length > MESSAGE_LIMIT

    result = RateLimitCounter.with_attempt(
      key: "ai_chat:#{current_user.id}:#{request.remote_ip}",
      limit: REQUEST_LIMIT,
      window: REQUEST_WINDOW
    ) { :invalid }
    if result == :throttled
      audit_security_event("ai_chat_throttled")
      response.set_header("Retry-After", REQUEST_WINDOW.to_i.to_s)
      return render json: {error: "Çok fazla istek gönderdiniz. Lütfen biraz sonra tekrar deneyin."}, status: :too_many_requests
    end

    service = AiAssistantService.new(user: current_user)
    response = service.ask(message)
    render json: {response: response, pending_actions: AiAction.pending_for(current_user).count}
  rescue AiAssistantService::Error => e
    audit_security_event("ai_chat_failed", error_class: e.class.name)
    render json: {error: e.message}, status: :service_unavailable
  end

  def destroy
    current_user.ai_conversations.delete_all
    render json: {success: true}
  end
end
