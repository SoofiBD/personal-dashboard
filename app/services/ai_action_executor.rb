# frozen_string_literal: true

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

      action.update!(status: "approved")
      result = ApplicationRecord.transaction { dispatch! }
      action.update!(status: "executed", executed_at: Time.current, result: result)
      result
    end
  rescue Error
    raise
  rescue
    action.update!(status: "failed", error_message: "İşlem tamamlanamadı.") if action.persisted?
    raise Error, "İşlem tamamlanamadı. Lütfen panelden kontrol edin."
  end

  private

  attr_reader :action, :user

  def dispatch!
    case action.action_type
    when "finance.create_expense", "finance.create_income" then create_transaction!
    when "finance.update_transaction" then update_transaction!
    when "finance.delete_transaction" then delete_transaction!
    when "learning.update_item" then update_learning_item!
    when "learning.record_attempt" then record_learning_attempt!
    when "learning.create_program" then create_learning_program!
    when "memory.remember" then remember!
    when "memory.forget" then forget!
    when "documents.update_content" then update_document_content!
    else raise Error, "Desteklenmeyen işlem."
    end
  end

  def create_transaction!
    raise Error, "Bu hesap için finans düzenleme yetkiniz yok." unless user.can_manage_finances?
    payload = action.payload
    amount = BigDecimal(payload.fetch("amount").to_s)
    raise Error, "Tutar sıfırdan büyük olmalıdır." unless amount.positive?
    kind = action.action_type.end_with?("expense") ? "expense" : "income"
    category = PersonalFinance::Category.find_by!(user: user, name: payload.fetch("category_name"), kind: kind)
    account = PersonalFinance::Account.find_by!(user: user, is_active: true)
    transaction = user.finance_transactions.create!(kind: kind, amount: amount, category: category, account: account, occurred_on: Date.current, note: payload.fetch("description"))
    {record_type: "transaction", record_id: transaction.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Kategori veya aktif hesap artık bulunamadı."
  end

  def update_transaction!
    raise Error, "Bu hesap için finans düzenleme yetkiniz yok." unless user.can_manage_finances?
    transaction = user.finance_transactions.find_by!(id: action.payload.fetch("id"))
    raise Error, "Bağlı transferler silinip yeniden oluşturulmalıdır." if transaction.transfer_group_id.present?
    attributes = action.payload.slice("amount", "note", "occurred_on").compact_blank
    attributes["amount"] = BigDecimal(attributes["amount"].to_s) if attributes["amount"]
    transaction.update!(attributes)
    {record_type: "transaction", record_id: transaction.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Finans hareketi artık bulunamadı."
  end

  def delete_transaction!
    raise Error, "Bu hesap için finans düzenleme yetkiniz yok." unless user.can_manage_finances?
    transaction = user.finance_transactions.find_by!(id: action.payload.fetch("id"))
    raise Error, "Bağlı transferler panelden silinmelidir." if transaction.transfer_group_id.present?
    transaction.destroy!
    {record_type: "transaction", record_id: transaction.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Finans hareketi artık bulunamadı."
  end

  def update_learning_item!
    item = user.learning_items.find_by!(id: action.payload.fetch("id"))
    item.update!(action.payload.slice("status", "confidence").compact_blank)
    {record_type: "learning_item", record_id: item.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Eğitim kaydı artık bulunamadı."
  end

  def record_learning_attempt!
    item = user.learning_items.find_by!(id: action.payload.fetch("item_id"))
    attempt = item.attempts.create!(action.payload.slice("outcome", "minutes", "confidence", "reflection").compact_blank)
    {record_type: "learning_attempt", record_id: attempt.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Eğitim kaydı artık bulunamadı."
  end

  def create_learning_program!
    items = action.payload.fetch("items")
    records = items.map do |attributes|
      user.learning_items.create!(attributes.slice("title", "track", "kind", "difficulty", "estimated_minutes", "target_on", "notes", "position").merge("status" => "planned", "confidence" => 0))
    end
    {record_type: "learning_program", record_ids: records.map(&:id), count: records.size}
  end

  def remember!
    payload = action.payload
    memory = user.ai_memories.find_or_initialize_by(key: payload.fetch("key"), category: payload.fetch("category"))
    memory.update!(value: payload.fetch("value"))
    {record_type: "memory", record_id: memory.id}
  end

  def forget!
    memory = user.ai_memories.find_by!(key: action.payload.fetch("key"))
    memory.destroy!
    {record_type: "memory", record_id: memory.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Hatırlanacak kayıt artık bulunamadı."
  end

  def update_document_content!
    raise Error, "Bu hesap için doküman düzenleme yetkiniz yok." unless user.can_manage_finances?
    document = user.document_conversions.completed.find_by!(id: action.payload.fetch("id"))
    document.update!(action.payload.slice("markdown_content", "custom_notes").compact_blank)
    {record_type: "document_conversion", record_id: document.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Düzenlenecek doküman artık bulunamadı veya hazır değil."
  end
end
