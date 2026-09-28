# frozen_string_literal: true

require "test_helper"

class AiAssistantServiceTest < ActiveSupport::TestCase
  test "uses the saved Gemini model" do
    user = User.dashboard_owner
    user.update!(ai_model: "gemini-3.7-flash")
    captured = nil

    with_env("GEMINI_API_KEY", "test-gemini-key") do
      replacement = lambda do |**options|
        captured = options
        Object.new
      end
      with_constructor_stub(Langchain::LLM::GoogleGemini, replacement) do
        AiAssistantService.new(user: user)
      end
    end

    assert_equal "gemini-3.7-flash", captured.dig(:default_options, :chat_model)
  end

  test "uses the active default for blank or shut down Gemini models" do
    user = User.dashboard_owner
    user.update!(ai_model: "gemini-2.0-flash")
    captured = nil

    with_env("GEMINI_API_KEY", "test-gemini-key") do
      replacement = lambda do |**options|
        captured = options
        Object.new
      end
      with_constructor_stub(Langchain::LLM::GoogleGemini, replacement) do
        AiAssistantService.new(user: user)
      end
    end

    assert_equal "gemini-3.6-flash", captured.dig(:default_options, :chat_model)
  end

  test "builds the LangChain assistant with supported options" do
    user = User.dashboard_owner
    service = with_env("GEMINI_API_KEY", "test-gemini-key") do
      AiAssistantService.new(user: user)
    end
    captured = nil
    assistant = Object.new

    with_constructor_stub(Langchain::Assistant, ->(**options) {
      captured = options
      assistant
    }) do
      assert_same assistant, service.send(:build_assistant, "Instructions")
    end

    assert_equal false, captured[:parallel_tool_calls]
    assert_not_includes captured.keys, :max_turns
  end

  test "converts Gemini client errors into the assistant error handled by the controller" do
    user = User.dashboard_owner
    service = with_env("GEMINI_API_KEY", "test-gemini-key") do
      AiAssistantService.new(user: user)
    end
    assistant = Object.new
    assistant.define_singleton_method(:add_message) { |role:, content:| }
    assistant.define_singleton_method(:add_message_and_run!) { |content:| raise StandardError, "provider request failed" }
    service.define_singleton_method(:build_assistant) { |_instructions| assistant }

    error = assert_raises(AiAssistantService::Error) { service.ask("Summarize my budget") }

    assert_equal "Asistan isteği tamamlayamadı. Lütfen tekrar deneyin.", error.message
  end

  private

  def with_constructor_stub(klass, replacement)
    original = klass.method(:new)
    constructor = replacement.respond_to?(:call) ? replacement : ->(**_options) { replacement }
    klass.define_singleton_method(:new, &constructor)
    yield
  ensure
    klass.define_singleton_method(:new, original)
  end

  def with_env(key, value)
    previous = ENV[key]
    ENV[key] = value
    yield
  ensure
    previous.nil? ? ENV.delete(key) : ENV[key] = previous
  end
end
