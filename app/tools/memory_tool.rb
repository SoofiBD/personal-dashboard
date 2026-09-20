# frozen_string_literal: true

class MemoryTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :remember, description: 'Save key-value memory. Params: key, value, category' do
    property :key, type: 'string', description: 'Memory key', required: true
    property :value, type: 'string', description: 'Memory value', required: true
    property :category, type: 'string', description: 'Category: user_pref, fact, context, reminder', required: true,
                        enum: %w[user_pref fact context reminder]
  end

  define_function :recall, description: 'Get memory by key' do
    property :key, type: 'string', description: 'Memory key', required: true
  end

  define_function :recall_by_category, description: 'List memories in category' do
    property :category, type: 'string', description: 'Category', required: true
  end

  define_function :forget, description: 'Delete memory by key' do
    property :key, type: 'string', description: 'Memory key', required: true
  end

  define_function :search_memories, description: 'Search memory values' do
    property :query, type: 'string', description: 'Search query', required: true
  end

  def remember(key:, value:, category:)
    memory = user.ai_memories.find_or_initialize_by(key: key, category: category)
    memory.value = value
    memory.save!
    tool_response(content: { success: true, key: key, category: category, value: value })
  end

  def recall(key:)
    memory = user.ai_memories.find_by(key: key)
    return tool_response(content: { error: "Memory '#{key}' not found" }) unless memory

    tool_response(content: { key: memory.key, value: memory.value, category: memory.category,
                             updated_at: memory.updated_at })
  end

  def recall_by_category(category:)
    memories = user.ai_memories.by_category(category).recent.map do |m|
      { key: m.key, value: m.value, updated_at: m.updated_at }
    end
    tool_response(content: memories)
  end

  def forget(key:)
    memory = user.ai_memories.find_by(key: key)
    return tool_response(content: { error: "Memory '#{key}' not found" }) unless memory

    memory.destroy!
    tool_response(content: { success: true, deleted_key: key })
  end

  def search_memories(query:)
    memories = user.ai_memories.where('value ILIKE ?', "%#{query}%").recent.limit(20).map do |m|
      { key: m.key, value: m.value, category: m.category, updated_at: m.updated_at }
    end
    tool_response(content: memories)
  end

  private

  attr_reader :user

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
