# frozen_string_literal: true

class AiActionsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_sensitive_caching
  before_action :set_action

  def approve
    result = AiActionExecutor.new(@action).execute!
    audit_security_event("ai_action_executed", action_id: @action.id, action_type: @action.action_type, result: result)
    redirect_to ai_assistant_path, notice: "İşlem uygulandı."
  rescue AiActionExecutor::Error => e
    audit_security_event("ai_action_failed", action_id: @action.id, action_type: @action.action_type)
    redirect_to ai_assistant_path, alert: e.message
  end

  def reject
    return redirect_to ai_assistant_path, alert: "Bu işlem artık beklemiyor." unless @action.status == "pending"
    if @action.expired?
      @action.expire_if_needed!
      return redirect_to ai_assistant_path, alert: "Bu işlemin onay süresi doldu."
    end

    @action.update!(status: "rejected")
    audit_security_event("ai_action_rejected", action_id: @action.id, action_type: @action.action_type)
    redirect_to ai_assistant_path, notice: "İşlem reddedildi."
  end

  private

  def set_action
    @action = current_user.ai_actions.find(params[:id])
  end
end
