# frozen_string_literal: true

# Applies a user-approved AiAction through the tool that proposed it (see AiTool::ACTIONS).
class AiActionExecutor
  class Error < StandardError; end

  def initialize(action)
    @action = action
    @user = action.user
  end

  def execute!
    action.with_lock do
      raise Error, "Bu işlem artık beklemiyor." unless action.status == "pending"
      raise Error, "Bu işlem için düzenleme yetkiniz yok." unless user.can_manage_workspace?
      if action.expired?
        action.expire_if_needed!
        raise Error, "Bu işlem için onay süresi doldu."
      end
      tool = AiTool.for_action(action.action_type) || raise(Error, "Desteklenmeyen işlem.")

      action.update!(status: "approved")
      result = ApplicationRecord.transaction { tool.new(user: user).apply(action) }
      action.update!(status: "executed", executed_at: Time.current, result: result)
      result
    end
  rescue Error
    raise
  rescue ActiveRecord::RecordNotFound
    raise Error, "İlgili kayıt artık bulunamadı."
  rescue
    action.update!(status: "failed", error_message: "İşlem tamamlanamadı.") if action.persisted?
    raise Error, "İşlem tamamlanamadı. Lütfen panelden kontrol edin."
  end

  private

  attr_reader :action, :user
end
