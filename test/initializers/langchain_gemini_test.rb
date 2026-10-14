# frozen_string_literal: true

require "test_helper"

class LangchainGeminiTest < ActiveSupport::TestCase
  test "sends Gemini tool results with the user role" do
    message = Langchain::Assistant::Messages::GoogleGeminiMessage.new(role: "function", content: "{}", tool_call_id: "finance_tool__list_accounts")

    assert_equal "user", message.to_hash[:role]
    assert_equal "finance_tool__list_accounts", message.to_hash.dig(:parts, 0, :functionResponse, :name)
  end
end
