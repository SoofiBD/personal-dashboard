# frozen_string_literal: true

require "test_helper"

class AiActionTest < ActiveSupport::TestCase
  test "expired pending actions are hidden and become expired" do
    user = User.dashboard_owner
    action = AiAction.propose!(
      user: user,
      action_type: "learning.create_program",
      payload: {"items" => [{"title" => "Week 1"}]},
      summary: "Plan"
    )
    action.update!(expires_at: 1.minute.ago)

    assert_not_includes AiAction.pending_for(user), action
    action.expire_if_needed!
    assert_equal "expired", action.reload.status
  end

  test "approved learning proposal writes only the current users items" do
    user = User.dashboard_owner
    action = AiAction.propose!(
      user: user,
      action_type: "learning.create_program",
      payload: {"items" => [{"title" => "Week 1"}]},
      summary: "Plan"
    )

    result = AiActionExecutor.new(action).execute!

    assert_equal "learning_program", result[:record_type]
    assert_equal ["Week 1"], user.learning_items.where(id: result[:record_ids]).pluck(:title)
    assert_equal "executed", action.reload.status
  end

  test "viewer cannot execute a pending finance proposal" do
    viewer = User.create!(name: "Viewer", email: "ai-viewer@example.test", role: "viewer", currency: "TRY", time_zone: "Europe/Istanbul")
    action = AiAction.propose!(user: viewer, action_type: "finance.create_expense", payload: {"amount" => "10", "category_name" => "Market", "description" => "Test"}, summary: "Expense")

    assert_raises(AiActionExecutor::Error) { AiActionExecutor.new(action).execute! }
    assert_empty viewer.finance_transactions
    assert_equal "pending", action.reload.status
  end

  test "oversized AI proposal cannot be approved without review" do
    assert_raises(ActiveRecord::RecordInvalid) do
      AiAction.propose!(user: User.dashboard_owner, action_type: "documents.update_content", payload: {"markdown_content" => "x" * 65_536}, summary: "Large edit")
    end
  end
end
