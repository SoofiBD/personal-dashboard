# frozen_string_literal: true

require "test_helper"

class AiAssistantServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.dashboard_owner
  end

  test "uses the saved Gemini model or the default for blank and shut down models" do
    @user.update!(ai_model: "gemini-3.7-flash")
    assert_equal "gemini-3.7-flash", AiAssistantService.model_for(@user)

    @user.update!(ai_model: "gemini-2.0-flash")
    assert_equal "gemini-3.6-flash", AiAssistantService.model_for(@user)

    @user.update!(ai_model: nil)
    assert_equal "gemini-3.6-flash", AiAssistantService.model_for(@user)
  end

  test "runs a requested tool and sends the model turn back with its thought signature" do
    model_turn = {"role" => "model", "parts" => [
      {"functionCall" => {"id" => "call-1", "name" => "get_overview", "args" => {}}, "thoughtSignature" => "sig-abc"}
    ]}
    requests = []
    replies = [
      {"candidates" => [{"content" => model_turn}]},
      {"candidates" => [{"content" => {"role" => "model", "parts" => [{"text" => "thinking", "thought" => true}, {"text" => "Bakiye hazır."}]}}]}
    ]

    reply = AiGeminiClient.stub(:generate, ->(model:, body:) { requests << JSON.parse(body.to_json) and replies.shift }) do
      AiAssistantService.new(user: @user).ask("Özet ver")
    end

    assert_equal "Bakiye hazır.", reply
    assert_equal "gemini-3.6-flash", AiAssistantService.model_for(@user)
    second = requests.last.fetch("contents")
    assert_equal model_turn, second[-2]
    response = second[-1].dig("parts", 0, "functionResponse")
    assert_equal "user", second[-1]["role"]
    assert_equal %w[call-1 get_overview], response.values_at("id", "name")
    assert response.dig("response", "result", "finance").key?("total_balance")
    assert_includes requests.first.dig("tools", 0, "functionDeclarations").map { |f| f["name"] }, "get_overview"
    assert_equal %w[user assistant], @user.ai_conversations.order(:created_at).pluck(:role)
  end

  test "replays saved history with Gemini roles" do
    AiConversation.create!(user: @user, role: "user", content: "Hello")
    AiConversation.create!(user: @user, role: "assistant", content: "Hi")
    sent = nil

    AiGeminiClient.stub(:generate, ->(model:, body:) { sent = body[:contents] and {"candidates" => [{"content" => {"parts" => [{"text" => "Ok"}]}}]} }) do
      AiAssistantService.new(user: @user).ask("Next")
    end

    assert_equal %w[user model user], sent.map { |c| c[:role] }
  end

  test "a failing tool call is reported to the model instead of failing the chat" do
    replies = [{"candidates" => [{"content" => {"parts" => [{"functionCall" => {"name" => "get_learning_item", "args" => {}}}]}}]}]
    sent = nil
    generate = lambda do |model:, body:|
      sent = body[:contents]
      replies.shift || {"candidates" => [{"content" => {"parts" => [{"text" => "Sorry"}]}}]}
    end

    reply = AiGeminiClient.stub(:generate, generate) { AiAssistantService.new(user: @user).ask("Hi") }

    assert_equal "Sorry", reply
    assert_equal({error: "Function get_learning_item failed"}, sent.last.dig(:parts, 0, :functionResponse, :response, :result))
  end

  test "maps Gemini errors to user-facing messages" do
    {unauthorized: AiProviderStatus::MESSAGES.fetch(:unauthorized), bad_request: AiAssistantService::GENERIC_ERROR}.each do |code, message|
      error = AiGeminiClient.stub(:generate, ->(**) { raise AiGeminiClient::Error.new(code) }) do
        assert_raises(AiAssistantService::Error) { AiAssistantService.new(user: @user).ask("Hello") }
      end
      assert_equal message, error.message
    end
  end
end
