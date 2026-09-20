# frozen_string_literal: true

class LearningTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :list_learning_items, description: 'Filter by status/track' do
    property :status, type: 'string', description: 'Status: planned, active, review, completed', required: false
    property :track, type: 'string', description: 'Track: interview, algorithms, system_engineering', required: false
  end

  define_function :get_learning_item, description: 'Item detail + attempts' do
    property :id, type: 'string', description: 'Item UUID', required: true
  end

  define_function :update_learning_item, description: 'Update status/confidence' do
    property :id, type: 'string', description: 'Item UUID', required: true
    property :status, type: 'string', description: 'New status', required: false
    property :confidence, type: 'integer', description: 'Confidence 0-5', required: false
  end

  define_function :record_attempt, description: 'Log practice. Params: item_id, outcome, minutes' do
    property :item_id, type: 'string', description: 'Item UUID', required: true
    property :outcome, type: 'string', description: 'Outcome: stuck, partial, solved', required: true
    property :minutes, type: 'integer', description: 'Minutes spent', required: true
    property :confidence, type: 'integer', description: 'Confidence 0-5', required: false
    property :reflection, type: 'string', description: 'Notes', required: false
  end

  def list_learning_items(status: nil, track: nil)
    items = user.learning_items
    items = items.where(status: status) if status.present?
    items = items.where(track: track) if track.present?

    result = items.order(:position).limit(30).map do |i|
      { id: i.id, title: i.title, track: i.track, kind: i.kind, status: i.status, difficulty: i.difficulty,
        confidence: i.confidence, position: i.position, estimated_minutes: i.estimated_minutes }
    end
    tool_response(content: result)
  end

  def get_learning_item(id:)
    item = user.learning_items.find_by(id: id)
    return tool_response(content: { error: 'Item not found' }) unless item

    attempts = item.attempts.order(created_at: :desc).limit(10).map do |a|
      { outcome: a.outcome, minutes: a.minutes, confidence: a.confidence, reflection: a.reflection,
        created_at: a.created_at }
    end

    tool_response(content: {
                    item: { id: item.id, title: item.title, track: item.track, kind: item.kind, status: item.status,
                            difficulty: item.difficulty, confidence: item.confidence, notes: item.notes, estimated_minutes: item.estimated_minutes, source_key: item.source_key },
                    attempts: attempts
                  })
  end

  def update_learning_item(id:, status: nil, confidence: nil)
    item = user.learning_items.find_by(id: id)
    return tool_response(content: { error: 'Item not found' }) unless item

    item.update!(status: status) if status.present?
    item.update!(confidence: confidence) if confidence.present?

    tool_response(content: { success: true, id: item.id, status: item.status, confidence: item.confidence })
  end

  def record_attempt(item_id:, outcome:, minutes:, confidence: nil, reflection: nil)
    item = user.learning_items.find_by(id: item_id)
    return tool_response(content: { error: 'Item not found' }) unless item

    attempt = item.attempts.create!(outcome: outcome, minutes: minutes, confidence: confidence || 0,
                                    reflection: reflection)
    tool_response(content: { success: true, attempt_id: attempt.id, item_title: item.title })
  end

  private

  attr_reader :user

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
