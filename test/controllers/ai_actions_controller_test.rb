require "test_helper"

class AiActionsControllerTest < PersonalFinance::IntegrationTest
  test "viewer cannot reject a pending action" do
    viewer = User.create!(name: "Viewer", email: "ai-action-viewer@example.test", role: "viewer", currency: "TRY", time_zone: "Europe/Istanbul", password: TEST_PASSWORD, password_confirmation: TEST_PASSWORD, onboarded_at: Time.current)
    action = AiAction.propose!(user: viewer, action_type: "gym.record_body_metric", payload: {"weight_kg" => "72", "recorded_on" => Date.current.iso8601}, summary: "Weight")
    delete session_path
    post session_path, params: {identifier: viewer.email, password: TEST_PASSWORD}

    post reject_ai_action_path(action)

    assert_redirected_to ai_assistant_path
    assert_equal "pending", action.reload.status
  end

  test "approval requires reviewing the exact escaped proposal payload" do
    action = AiAction.propose!(
      user: User.dashboard_owner,
      action_type: "learning.create_program",
      payload: {"items" => [{"title" => "Week 1 <script>alert(1)</script>", "target_on" => "2026-10-01"}]},
      summary: "New course"
    )

    get ai_assistant_path

    assert_response :success
    assert_select ".ai-action-review pre", text: /Week 1 <script>alert\(1\)<\/script>/
    assert_select ".ai-action-review pre", text: /2026-10-01/
    assert_select ".ai-action-review script", count: 0
    assert_select ".ai-action-review form[action='#{approve_ai_action_path(action)}']", count: 1
  end
end
