# frozen_string_literal: true

require "test_helper"

class AiAssistantServiceTest < ActiveSupport::TestCase
  test "uses the saved Gemini model" do
    user = User.dashboard_owner
    user.update!(ai_model: "gemini-2.0-flash-lite")
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

    assert_equal "gemini-2.0-flash-lite", captured.dig(:default_options, :chat_model)
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
