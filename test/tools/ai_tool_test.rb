# frozen_string_literal: true

require "test_helper"

class AiToolTest < ActiveSupport::TestCase
  test "registry exposes unique Gemini declarations and appliers for every action type" do
    names = AiTool.declarations.map { |declaration| declaration[:name] }
    assert_equal names.uniq, names
    assert_nil DashboardTool.functions.fetch("get_overview")[:parameters], "Gemini rejects empty object schemas"

    AiTool.all.each do |tool|
      tool.functions.each_key { |name| assert tool.public_method_defined?(name), "#{tool}##{name} missing" }
      tool::ACTIONS.each_value { |method| assert tool.public_method_defined?(method), "#{tool}##{method} missing" }
    end
    assert_includes AiTool.action_types, "finance.create_expense"
    assert_equal FinanceTool, AiTool.for_action("finance.create_expense")
  end

  test "call runs only declared functions with declared parameters" do
    tool = LearningTool.new(user: User.dashboard_owner)

    assert_kind_of Array, tool.call("list_learning_items", {"status" => "active", "user_id" => "someone-else"})
    assert_raises(KeyError) { tool.call("apply_create_program", {}) }
  end

  test "recent activity merges transactions and attempts newest first" do
    user = User.dashboard_owner
    item = user.learning_items.create!(title: "Graphs", track: "algorithms", kind: "topic", status: "active", difficulty: "medium", confidence: 0, estimated_minutes: 30)
    item.attempts.create!(user: user, outcome: "solved", minutes: 20, confidence: 3)

    activity = DashboardTool.new(user: user).get_recent_activity(days: 3)

    assert_includes activity.map { |entry| entry[:type] }, "learning_attempt"
    assert_equal activity.map { |entry| entry[:at] }.sort.reverse, activity.map { |entry| entry[:at] }
  end

  test "expense proposal is rejected early for an unknown category" do
    result = FinanceTool.new(user: User.dashboard_owner).create_expense(amount: 10, category_name: "No such category", description: "x")

    assert_match(/Unknown expense category/, result[:error])
    assert_equal 0, AiAction.count
  end
end
