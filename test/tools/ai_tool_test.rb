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

  test "expense is rejected early for an unknown category and lists the real ones" do
    user = User.dashboard_owner
    PersonalFinance::Category.create!(user: user, name: "Market", kind: :expense, color: "#EF4444")
    result = FinanceTool.new(user: user).create_expense(amount: 10, category_name: "No such category", description: "x")

    assert_match(/Unknown expense category/, result[:error])
    assert_equal ["Market"], result[:available_categories]
    assert_equal 0, AiAction.count
  end

  test "expense and income are recorded at once with date and account, and logged" do
    user = User.dashboard_owner
    user.financial_accounts.create!(name: "Nakit", kind: "cash", opening_balance: 0, currency: "TRY", is_active: true)
    bank = user.financial_accounts.create!(name: "Banka", kind: "bank", opening_balance: 0, currency: "TRY", is_active: true)
    PersonalFinance::Category.create!(user: user, name: "Market", kind: :expense, color: "#EF4444")
    PersonalFinance::Category.create!(user: user, name: "Maaş", kind: :income, color: "#10B981")
    tool = FinanceTool.new(user: user)

    expense = tool.call("create_expense", {"amount" => 250, "category_name" => "Market", "description" => "Haftalık", "occurred_on" => Date.yesterday.iso8601, "account_name" => "Banka"})
    income = tool.call("create_income", {"amount" => 5000, "category_name" => "Maaş", "description" => "Kasım"})

    assert expense[:done], expense.inspect
    assert income[:done], income.inspect
    spent = user.finance_transactions.find(expense[:record_id])
    assert_equal [250, Date.yesterday, bank], [spent.amount, spent.occurred_on, spent.account]
    assert_equal Date.current, user.finance_transactions.find(income[:record_id]).occurred_on
    assert_equal %w[executed executed], AiAction.order(:created_at).pluck(:status)
  end

  test "expense rejects future dates and unknown accounts without writing" do
    user = User.dashboard_owner
    user.financial_accounts.create!(name: "Nakit", kind: "cash", opening_balance: 0, currency: "TRY", is_active: true)
    PersonalFinance::Category.create!(user: user, name: "Market", kind: :expense, color: "#EF4444")
    tool = FinanceTool.new(user: user)

    assert_match(/not in the future/, tool.create_expense(amount: 5, category_name: "Market", description: "x", occurred_on: Date.tomorrow.iso8601)[:error])
    assert_equal ["Nakit"], tool.create_expense(amount: 5, category_name: "Market", description: "x", account_name: "Yok")[:available_accounts]
    assert_equal 0, user.finance_transactions.count
  end

  test "subscription is added at once but removal waits for approval" do
    user = User.dashboard_owner
    tool = FinanceTool.new(user: user)

    added = tool.call("create_subscription", {"name" => "Netflix", "amount" => 200, "billing_interval" => "monthly"})
    subscription = user.finance_subscriptions.find(added[:record_id])
    assert_equal ["Netflix", 200, "monthly"], [subscription.name, subscription.amount, subscription.billing_interval]
    assert_equal subscription.id, tool.list_subscriptions.first[:id]

    removal = tool.call("delete_subscription", {"id" => subscription.id})
    assert removal[:requires_confirmation]
    assert user.finance_subscriptions.exists?(subscription.id)

    AiActionExecutor.new(AiAction.find(removal[:action_id])).execute!
    assert_not user.finance_subscriptions.exists?(subscription.id)
  end
end
