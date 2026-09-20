# frozen_string_literal: true

class AiAssistantService
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~TEXT
    Personal dashboard AI. Use tools for all data access. Never guess records. Only mutate when asked. Save user facts with MemoryTool.remember when told. Respond concisely. Locale: {locale} -> respond in that language. Currency: {currency}. Today: {date}.
  TEXT

  def initialize(user:)
    @user = user
    @llm = Langchain::LLM::GoogleGemini.new(
      api_key: ENV.fetch('GEMINI_API_KEY'),
      default_options: { chat_model: 'gemini-2.0-flash', temperature: 0.2 }
    )
  end

  def ask(user_message)
    raise Error, 'Empty message' if user_message.blank?

    instructions = build_instructions
    assistant = build_assistant(instructions)

    replay_conversation_history(assistant)
    assistant.add_message_and_run!(content: user_message)

    response = assistant.messages.last&.content || 'No response generated'
    save_exchange(user_message, response)
    cleanup_old_conversations

    response
  rescue Langchain::LLM::GoogleGemini::Error => e
    raise Error, "Gemini API error: #{e.message}"
  rescue StandardError => e
    raise Error, "Assistant error: #{e.message}"
  end

  private

  attr_reader :user, :llm

  def build_instructions
    SYSTEM_PROMPT
      .gsub('{locale}', user.locale)
      .gsub('{currency}', user.currency)
      .gsub('{date}', Date.current.strftime('%Y-%m-%d'))
  end

  def build_assistant(instructions)
    tools = [
      FinanceTool.new(user: user),
      NotesTool.new(user: user),
      LearningTool.new(user: user),
      GymTool.new(user: user),
      MemoryTool.new(user: user),
      DashboardTool.new(user: user)
    ]

    Langchain::Assistant.new(
      llm: llm,
      instructions: instructions,
      tools: tools,
      parallel_tool_calls: false,
      max_turns: 5
    )
  end

  def replay_conversation_history(assistant)
    history = AiConversation.recent_for(user, limit: 10).reverse
    history.each do |msg|
      next if msg.content.blank?

      case msg.role
      when 'user', 'assistant'
        assistant.add_message(role: msg.role, content: msg.content)
      when 'tool'
        assistant.add_message(role: 'tool', content: msg.content)
      end
    end
  end

  def save_exchange(user_msg, assistant_msg)
    AiConversation.create!(user: user, role: 'user', content: user_msg)
    AiConversation.create!(user: user, role: 'assistant', content: assistant_msg)
  end

  def cleanup_old_conversations
    AiConversation.cleanup_old(days: 3).where(user: user).delete_all
  end
end
