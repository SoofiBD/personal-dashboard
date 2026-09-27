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
  rescue => e
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
    when "notes.create" then create_note!
    when "notes.update" then update_note!
    when "notes.delete" then delete_note!
    when "learning.update_item" then update_learning_item!
    when "learning.record_attempt" then record_learning_attempt!
    when "learning.create_program" then create_learning_program!
    when "gym.create_program" then create_gym_program!
    when "gym.record_body_metric" then record_body_metric!
    when "gym.schedule_workout" then schedule_workout!
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

  def create_note!
    raise Error, "Bu hesap için not düzenleme yetkiniz yok." unless user.can_manage_notes?
    payload = action.payload
    note = user.notes.create!(title: payload.fetch("title"), body: payload.fetch("body"), tag_list: payload.fetch("tags", ""))
    note.sync_links!
    {record_type: "note", record_id: note.id}
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

  def update_note!
    raise Error, "Bu hesap için not düzenleme yetkiniz yok." unless user.can_manage_notes?
    note = user.notes.find_by!(id: action.payload.fetch("id"))
    note.update!(action.payload.slice("title", "body", "tags", "pinned").compact_blank)
    note.sync_links!
    {record_type: "note", record_id: note.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Not artık bulunamadı."
  end

  def delete_note!
    raise Error, "Bu hesap için not düzenleme yetkiniz yok." unless user.can_manage_notes?
    note = user.notes.find_by!(id: action.payload.fetch("id"))
    note.destroy!
    {record_type: "note", record_id: note.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Not artık bulunamadı."
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

  def create_gym_program!
    payload = action.payload
    routine = user.gym_routines.create!(name: payload.fetch("name"), description: payload["description"])
    payload.fetch("days").each_with_index do |day_data, day_index|
      day = routine.days.create!(name: day_data.fetch("name"), position: day_index + 1)
      day_data.fetch("exercises").each_with_index do |exercise_data, exercise_index|
        exercise = PersonalGym::Exercise.find(exercise_data.fetch("exercise_id"))
        day.routine_exercises.create!(
          exercise: exercise, position: exercise_index + 1, target_sets: exercise_data.fetch("sets"),
          target_reps: exercise_data["reps"], target_weight: exercise_data["weight"],
          target_duration_seconds: exercise_data["duration_seconds"], progression_policy: exercise_data.fetch("progression_policy"),
          warmup: exercise_data["warmup"]
        )
      end
    end
    {record_type: "gym_routine", record_id: routine.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Programdaki bir hareket artık katalogda bulunamadı."
  end

  def record_body_metric!
    payload = action.payload
    metric = user.gym_body_metrics.find_or_initialize_by(recorded_on: payload.fetch("recorded_on"))
    metric.update!(weight_kg: payload.fetch("weight_kg"), note: payload["note"])
    {record_type: "gym_body_metric", record_id: metric.id}
  end

  def schedule_workout!
    payload = action.payload
    day = PersonalGym::RoutineDay.joins(:routine).find_by!(id: payload.fetch("routine_day_id"), gym_routines: {user_id: user.id})
    entry = user.gym_schedule_entries.find_or_create_by!(routine_day: day, scheduled_on: payload.fetch("scheduled_on"))
    {record_type: "gym_schedule_entry", record_id: entry.id}
  rescue ActiveRecord::RecordNotFound
    raise Error, "Planlanacak antrenman günü artık bulunamadı."
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
