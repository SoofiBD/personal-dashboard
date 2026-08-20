module PersonalFinance
  class BudgetAllocation < ApplicationRecord
    self.table_name = "finance_budget_allocations"

    belongs_to :budget_period, class_name: "PersonalFinance::BudgetPeriod"
    belongs_to :category, class_name: "PersonalFinance::Category"

    validates :category_id, uniqueness: { scope: :budget_period_id }
    validates :planned_amount, numericality: { greater_than_or_equal_to: 0 }
    validate :expense_category_owned_by_budget_user

    def spent
      PersonalFinance::Transaction.where(user_id: budget_period.user_id, category_id: category_id, kind: "expense", occurred_on: budget_period.starts_on..budget_period.ends_on).sum(:amount)
    end

    def remaining
      planned_amount - spent
    end

    private

    def expense_category_owned_by_budget_user
      return unless budget_period && category
      errors.add(:category, "is invalid") unless category.user_id == budget_period.user_id && category.expense?
    end
  end
end
