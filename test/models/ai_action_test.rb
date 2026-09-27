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
end
