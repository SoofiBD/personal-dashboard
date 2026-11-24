# frozen_string_literal: true

class MemoryTool < AiTool
  CATEGORIES = %w[user_pref fact context reminder].freeze
  ACTIONS = {
    "memory.remember" => :apply_remember,
    "memory.forget" => :apply_forget
  }.freeze

  function :remember, "Propose saving a key-value memory the user explicitly asked to remember; user confirmation is required",
    required: %i[key value category],
    key: {type: "string", description: "Memory key"},
    value: {type: "string", description: "Memory value"},
    category: {type: "string", description: "Category", enum: CATEGORIES}
  function :recall, "Get a memory by key",
    required: %i[key],
    key: {type: "string", description: "Memory key"}
  function :recall_by_category, "List memories in a category",
    required: %i[category],
    category: {type: "string", description: "Category", enum: CATEGORIES}
  function :forget, "Propose deleting a memory by key; user confirmation is required",
    required: %i[key],
    key: {type: "string", description: "Memory key"}
  function :search_memories, "Search memory values",
    required: %i[query],
    query: {type: "string", description: "Search text"}

  def remember(key:, value:, category:)
    return {error: "Unknown category"} unless CATEGORIES.include?(category)

    propose("memory.remember", {key: key, value: value, category: category}, "Asistan hafızasına kaydet: #{key}")
  end

  def recall(key:)
    memory = user.ai_memories.find_by(key: key)
    return {error: "Memory '#{key}' not found"} unless memory

    {key: memory.key, value: memory.value, category: memory.category, updated_at: memory.updated_at}
  end

  def recall_by_category(category:)
    user.ai_memories.by_category(category).recent.map { |m| {key: m.key, value: m.value, updated_at: m.updated_at} }
  end

  def forget(key:)
    return {error: "Memory '#{key}' not found"} unless user.ai_memories.exists?(key: key)

    propose("memory.forget", {key: key}, "Asistan hafızasından sil: #{key}")
  end

  def search_memories(query:)
    pattern = "%#{AiMemory.sanitize_sql_like(query.to_s)}%"
    user.ai_memories.where("value ILIKE ?", pattern).recent.limit(20).map do |m|
      {key: m.key, value: m.value, category: m.category, updated_at: m.updated_at}
    end
  end

  def apply_remember(payload)
    memory = user.ai_memories.find_or_initialize_by(key: payload.fetch("key"), category: payload.fetch("category"))
    memory.update!(value: payload.fetch("value"))
    {record_type: "memory", record_id: memory.id}
  end

  def apply_forget(payload)
    memory = user.ai_memories.find_by!(key: payload.fetch("key"))
    memory.destroy!
    {record_type: "memory", record_id: memory.id}
  end
end
