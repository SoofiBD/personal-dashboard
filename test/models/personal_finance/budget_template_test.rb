require "test_helper"

class PersonalFinance::BudgetTemplateTest < ActiveSupport::TestCase
  test "predefined templates are created for a user" do
    user = User.dashboard_owner

    PersonalFinance::BudgetTemplate.ensure_predefined_for!(user)

    assert_equal %w[Aile Çalışan Öğrenci], user.finance_budget_templates.where(predefined: true).order(:name).pluck(:name)
  end

  test "a template applies matching category allocations to a budget" do
    user = User.dashboard_owner
    food = PersonalFinance::Category.create!(user: user, name: "Food", kind: "expense", color: "#3B82F6")
    budget = PersonalFinance::BudgetPeriod.create!(user: user, starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 3, 31))
    template = PersonalFinance::BudgetTemplate.create!(user: user, name: "Food plan", allocation_data: [{"category_name" => "Food", "planned_amount" => "1200"}])

    template.apply_to!(budget)

    assert_equal 1200, budget.reload.planned_income.to_f
    assert_equal 1200, budget.allocations.find_by!(category: food).planned_amount.to_f
  end
end
