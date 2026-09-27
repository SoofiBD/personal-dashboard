# frozen_string_literal: true

class LearningTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :list_learning_items, description: "Filter by status/track" do
    property :status, type: "string", description: "Status: planned, active, review, completed", required: false
    property :track, type: "string", description: "Track: interview, algorithms, system_engineering", required: false
  end

  define_function :get_learning_item, description: "Item detail + attempts" do
    property :id, type: "string", description: "Item UUID", required: true
  end

  define_function :update_learning_item, description: "Update status/confidence" do
    property :id, type: "string", description: "Item UUID", required: true
    property :status, type: "string", description: "New status", required: false
    property :confidence, type: "integer", description: "Confidence 0-5", required: false
  end

  define_function :record_attempt, description: "Log practice. Params: item_id, outcome, minutes" do
    property :item_id, type: "string", description: "Item UUID", required: true
    property :outcome, type: "string", description: "Outcome: stuck, partial, solved", required: true
    property :minutes, type: "integer", description: "Minutes spent", required: true
    property :confidence, type: "integer", description: "Confidence 0-5", required: false
    property :reflection, type: "string", description: "Notes", required: false
  end

  define_function :create_program, description: "Propose a weekly or monthly learning plan from the user's supplied program. plan_json must be valid JSON: {\"name\":\"...\",\"items\":[{\"title\":\"...\",\"track\":\"algorithms\",\"kind\":\"topic\",\"difficulty\":\"medium\",\"estimated_minutes\":60,\"target_on\":\"2026-10-01\",\"notes\":\"...\"}]}. This only creates one confirmation proposal; it never writes directly." do
    property :plan_json, type: "string", description: "Complete learning plan as valid JSON", required: true
  end

  def list_learning_items(status: nil, track: nil)
    items = user.learning_items
    items = items.where(status: status) if status.present?
    items = items.where(track: track) if track.present?

    result = items.order(:position).limit(30).map do |i|
      {id: i.id, title: i.title, track: i.track, kind: i.kind, status: i.status, difficulty: i.difficulty,
       confidence: i.confidence, position: i.position, estimated_minutes: i.estimated_minutes}
    end
    tool_response(content: result)
  end

  def get_learning_item(id:)
    item = user.learning_items.find_by(id: id)
    return tool_response(content: {error: "Item not found"}) unless item

    attempts = item.attempts.order(created_at: :desc).limit(10).map do |a|
      {outcome: a.outcome, minutes: a.minutes, confidence: a.confidence, reflection: a.reflection,
       created_at: a.created_at}
    end

    tool_response(content: {
      item: {id: item.id, title: item.title, track: item.track, kind: item.kind, status: item.status,
             difficulty: item.difficulty, confidence: item.confidence, notes: item.notes, estimated_minutes: item.estimated_minutes, source_key: item.source_key},
      attempts: attempts
    })
  end

  def update_learning_item(id:, status: nil, confidence: nil)
    item = user.learning_items.find_by(id: id)
    return tool_response(content: {error: "Item not found"}) unless item
    action = AiAction.propose!(user: user, action_type: "learning.update_item", payload: {id: item.id, status: status, confidence: confidence}.compact, summary: "Eğitim kaydını güncelle: #{item.title}")
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  end

  def record_attempt(item_id:, outcome:, minutes:, confidence: nil, reflection: nil)
    item = user.learning_items.find_by(id: item_id)
    return tool_response(content: {error: "Item not found"}) unless item
    action = AiAction.propose!(user: user, action_type: "learning.record_attempt", payload: {item_id: item.id, outcome: outcome, minutes: minutes, confidence: confidence, reflection: reflection}.compact, summary: "Çalışma kaydı ekle: #{item.title}")
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  end

  def create_program(plan_json:)
    plan = JSON.parse(plan_json)
    validated = validate_program!(plan)
    action = AiAction.propose!(
      user: user,
      action_type: "learning.create_program",
      payload: validated,
      summary: "Eğitim planı oluştur: #{validated.fetch("name")} (#{validated.fetch("items").size} kayıt)"
    )
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  rescue JSON::ParserError
    tool_response(content: {error: "Eğitim planı geçerli JSON olmalıdır."})
  rescue ArgumentError => e
    tool_response(content: {error: e.message})
  end

  private

  attr_reader :user

  def validate_program!(plan)
    raise ArgumentError, "Plan bir JSON nesnesi olmalıdır." unless plan.is_a?(Hash)
    name = plan["name"].to_s.strip
    items = plan["items"]
    raise ArgumentError, "Plan adı gereklidir." if name.blank? || name.length > 120
    raise ArgumentError, "Plan 1-40 kayıt içermelidir." unless items.is_a?(Array) && items.size.between?(1, 40)

    {"name" => name, "items" => items.each_with_index.map do |item, index|
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
  rescue KeyError, ArgumentError => e
    raise ArgumentError, e.message
  end

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
