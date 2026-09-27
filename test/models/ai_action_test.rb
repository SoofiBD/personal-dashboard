# frozen_string_literal: true

require "test_helper"

class AiActionTest < ActiveSupport::TestCase
  test "expired pending actions are hidden and become expired" do
    user = User.dashboard_owner
    action = AiAction.propose!(
      user: user,
      action_type: "gym.record_body_metric",
      payload: {"weight_kg" => "75.0", "recorded_on" => Date.current.iso8601},
      summary: "Vücut ağırlığı kaydet"
    )
    action.update!(expires_at: 1.minute.ago)

    assert_not_includes AiAction.pending_for(user), action
    action.expire_if_needed!
    assert_equal "expired", action.reload.status
  end

  test "approved body-weight proposal writes only the current users metric" do
    user = User.dashboard_owner
    action = AiAction.propose!(
      user: user,
      action_type: "gym.record_body_metric",
      payload: {"weight_kg" => "74.5", "recorded_on" => Date.current.iso8601, "note" => "Sabah"},
      summary: "Vücut ağırlığı kaydet"
    )

    result = AiActionExecutor.new(action).execute!

    assert_equal "gym_body_metric", result[:record_type]
    metric = user.gym_body_metrics.find(result[:record_id])
    assert_equal 74.5, metric.weight_kg.to_f
    assert_equal "executed", action.reload.status
  end

  test "viewer cannot execute a pending gym proposal" do
    viewer = User.create!(name: "Viewer", email: "ai-viewer@example.test", role: "viewer", currency: "TRY", time_zone: "Europe/Istanbul")
    action = AiAction.propose!(user: viewer, action_type: "gym.record_body_metric", payload: {"weight_kg" => "74.5", "recorded_on" => Date.current.iso8601}, summary: "Weight")

    assert_raises(AiActionExecutor::Error) { AiActionExecutor.new(action).execute! }
    assert_empty viewer.gym_body_metrics
    assert_equal "pending", action.reload.status
  end

  test "oversized AI proposal cannot be approved without review" do
    assert_raises(ActiveRecord::RecordInvalid) do
      AiAction.propose!(user: User.dashboard_owner, action_type: "documents.update_content", payload: {"markdown_content" => "x" * 65_536}, summary: "Large edit")
    end
  end
end
