# frozen_string_literal: true

class LearningTool < AiTool
  ACTIONS = {
    "learning.update_item" => :apply_update_item,
    "learning.record_attempt" => :apply_record_attempt,
    "learning.create_program" => :apply_create_program
  }.freeze

  function :list_learning_items, "Learning items, optionally filtered by status/track",
    status: {type: "string", description: "Status", enum: Learning::Item::STATUSES},
    track: {type: "string", description: "Track", enum: Learning::Item::TRACKS}
  function :get_learning_item, "Learning item detail with recent attempts",
    required: %i[id],
    id: {type: "string", description: "Item id"}
  function :update_learning_item, "Propose updating an item's status/confidence; user confirmation is required",
    required: %i[id],
    id: {type: "string", description: "Item id"},
    status: {type: "string", description: "New status", enum: Learning::Item::STATUSES},
    confidence: {type: "integer", description: "Confidence 0-5"}
  function :record_attempt, "Propose logging a practice attempt; user confirmation is required",
    required: %i[item_id outcome minutes confidence],
    item_id: {type: "string", description: "Item id"},
    outcome: {type: "string", description: "Outcome", enum: Learning::Attempt::OUTCOMES},
    minutes: {type: "integer", description: "Minutes spent"},
    confidence: {type: "integer", description: "Confidence 0-5"},
    reflection: {type: "string", description: "Notes"}
  function :create_program,
    "Propose a weekly or monthly learning plan from the user's supplied program. plan_json must be valid JSON: " \
    "{\"name\":\"...\",\"items\":[{\"title\":\"...\",\"track\":\"algorithms\",\"kind\":\"topic\",\"difficulty\":\"medium\"," \
    "\"estimated_minutes\":60,\"target_on\":\"2026-10-01\",\"notes\":\"...\"}]}. This only creates one confirmation proposal; it never writes directly.",
    required: %i[plan_json],
    plan_json: {type: "string", description: "Complete learning plan as valid JSON"}

  def list_learning_items(status: nil, track: nil)
    items = user.learning_items
    items = items.where(status: status) if status.present?
    items = items.where(track: track) if track.present?
    items.order(:position).limit(30).map do |i|
      {id: i.id, title: i.title, track: i.track, kind: i.kind, status: i.status, difficulty: i.difficulty,
       confidence: i.confidence, position: i.position, estimated_minutes: i.estimated_minutes}
    end
  end

  def get_learning_item(id:)
    item = user.learning_items.find_by(id: id)
    return {error: "Item not found"} unless item

    attempts = item.attempts.order(created_at: :desc).limit(10).map do |a|
      {outcome: a.outcome, minutes: a.minutes, confidence: a.confidence, reflection: a.reflection, created_at: a.created_at}
    end
    {
      item: {id: item.id, title: item.title, track: item.track, kind: item.kind, status: item.status, difficulty: item.difficulty,
             confidence: item.confidence, notes: item.notes, estimated_minutes: item.estimated_minutes, source_key: item.source_key},
      attempts: attempts
    }
  end

  def update_learning_item(id:, status: nil, confidence: nil)
    item = user.learning_items.find_by(id: id)
    return {error: "Item not found"} unless item
    payload = {id: item.id, status: status, confidence: confidence}.compact
    return {error: "No change supplied"} if payload.except(:id).empty?

    propose("learning.update_item", payload, "Eğitim kaydını güncelle: #{item.title}")
  end

  def record_attempt(item_id:, outcome:, minutes:, confidence:, reflection: nil)
    item = user.learning_items.find_by(id: item_id)
    return {error: "Item not found"} unless item

    propose("learning.record_attempt", {item_id: item.id, outcome: outcome, minutes: minutes, confidence: confidence, reflection: reflection}.compact, "Çalışma kaydı ekle: #{item.title}")
  end

  def create_program(plan_json:)
    plan = validate_program!(JSON.parse(plan_json))
    propose("learning.create_program", plan, "Eğitim planı oluştur: #{plan.fetch("name")} (#{plan.fetch("items").size} kayıt)")
  rescue JSON::ParserError
    {error: "Eğitim planı geçerli JSON olmalıdır."}
  rescue ArgumentError, KeyError, TypeError => e
    {error: e.message}
  end

  def apply_update_item(payload)
    item = user.learning_items.find(payload.fetch("id"))
    item.update!(payload.slice("status", "confidence").compact_blank)
    {record_type: "learning_item", record_id: item.id}
  end

  def apply_record_attempt(payload)
    item = user.learning_items.find(payload.fetch("item_id"))
    attempt = item.attempts.create!(payload.slice("outcome", "minutes", "confidence", "reflection").compact_blank.merge(user: user))
    {record_type: "learning_attempt", record_id: attempt.id}
  end

  def apply_create_program(payload)
    records = payload.fetch("items").map do |attributes|
      user.learning_items.create!(attributes.slice("title", "track", "kind", "difficulty", "estimated_minutes", "target_on", "notes", "position").merge("status" => "planned", "confidence" => 0))
    end
    {record_type: "learning_program", record_ids: records.map(&:id), count: records.size}
  end

  private

  def validate_program!(plan)
    raise ArgumentError, "Plan bir JSON nesnesi olmalıdır." unless plan.is_a?(Hash)
    name = plan["name"].to_s.strip
    items = plan["items"]
    raise ArgumentError, "Plan adı gereklidir." if name.blank? || name.length > 120
    raise ArgumentError, "Plan 1-40 kayıt içermelidir." unless items.is_a?(Array) && items.size.between?(1, 40)

    {"name" => name, "items" => items.each_with_index.map do |item, index|
      raise ArgumentError, "#{index + 1}. kayıt bir JSON nesnesi olmalıdır." unless item.is_a?(Hash)
      title = item["title"].to_s.strip
      track = item.fetch("track", "interview").to_s
      kind = item.fetch("kind", "topic").to_s
      difficulty = item.fetch("difficulty", "medium").to_s
      minutes = Integer(item.fetch("estimated_minutes", 30))
      raise ArgumentError, "#{index + 1}. kayıt başlığı geçersiz." if title.blank? || title.length > 200
      raise ArgumentError, "#{title} için geçersiz eğitim alanı." unless Learning::Item::TRACKS.include?(track)
      raise ArgumentError, "#{title} için geçersiz kayıt türü." unless Learning::Item::KINDS.include?(kind)
      raise ArgumentError, "#{title} için geçersiz zorluk." unless Learning::Item::DIFFICULTIES.include?(difficulty)
      raise ArgumentError, "#{title} için süre 1-1440 dakika olmalıdır." unless minutes.between?(1, 1440)
      target_on = item["target_on"].present? ? Date.iso8601(item["target_on"].to_s).iso8601 : nil
      {"title" => title, "track" => track, "kind" => kind, "difficulty" => difficulty, "estimated_minutes" => minutes,
       "target_on" => target_on, "notes" => item["notes"].to_s.first(50_000), "position" => index + 1}
    end}
  end
end
