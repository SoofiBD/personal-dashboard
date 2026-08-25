require "test_helper"

class PersonalFinance::RecurringRuleTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Recurring User", currency: "TRY", time_zone: "Europe/Istanbul")
    @account = PersonalFinance::Account.create!(user: @user, name: "Main", kind: :bank, opening_balance: 0)
    @category = PersonalFinance::Category.create!(user: @user, name: "Rent", kind: :expense, color: "#EF4444")
  end

  test "generates each missed occurrence once" do
    starts_on = Date.current - 2.weeks
    rule = recurring_rule(starts_on: starts_on, last_generated_on: starts_on)
    PersonalFinance::Transaction.create!(user: @user, account: @account, category: @category, recurring_rule: rule, kind: :expense, amount: 100, occurred_on: starts_on, is_recurring: true)

    PersonalFinance::RecurringTransactionGenerator.generate_due_for(@user)
    PersonalFinance::RecurringTransactionGenerator.generate_due_for(@user)

    assert_equal 3, rule.transactions.count
    assert_equal 3, rule.reload.generated_count
    assert_equal Date.current, rule.last_generated_on
  end

  test "does not generate while paused or after its count limit" do
    paused = recurring_rule(is_paused: true)
    limited = recurring_rule(recurrence_count: 1)

    PersonalFinance::RecurringTransactionGenerator.generate_due_for(@user, through: Date.current + 1.month)

    assert_equal 0, paused.transactions.count
    assert_equal 0, limited.transactions.count
  end

  test "does not generate after a rule is stopped" do
    rule = recurring_rule(stopped_at: Time.current)

    PersonalFinance::RecurringTransactionGenerator.generate_due_for(@user, through: Date.current + 1.month)

    assert_equal 0, rule.transactions.count
  end

  private

  def recurring_rule(attributes = {})
    {
      user: @user,
      account: @account,
      category: @category,
      kind: :expense,
      amount: 100,
      note: "Rent",
      starts_on: Date.current - 1.week,
      last_generated_on: Date.current - 1.week,
      recurrence_interval: :weekly
    }.merge(attributes).then { |params| PersonalFinance::RecurringRule.create!(params) }
  end
end
