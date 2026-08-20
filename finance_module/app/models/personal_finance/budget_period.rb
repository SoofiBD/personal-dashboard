module PersonalFinance
  class BudgetPeriod < ApplicationRecord
    self.table_name = "finance_budget_periods"

    belongs_to :user, class_name: "::User"
    has_many :allocations, class_name: "PersonalFinance::BudgetAllocation", foreign_key: :budget_period_id, dependent: :destroy

    validates :starts_on, :ends_on, presence: true
    validates :starts_on, uniqueness: {scope: :user_id}
    validates :planned_income, numericality: {greater_than_or_equal_to: 0}
    validate :whole_month

    def expenses
      PersonalFinance::Transaction.where(user_id: user_id, kind: "expense", occurred_on: starts_on..ends_on)
    end

    def planned_spending
      allocations.sum(:planned_amount)
    end

    def actual_spending
      expenses.sum(:amount)
    end

    def remaining
      planned_spending - actual_spending
    end

    private

    def whole_month
      return unless starts_on && ends_on
      errors.add(:ends_on, "must be the end of the same month") unless starts_on == starts_on.beginning_of_month && ends_on == starts_on.end_of_month
    end
  end
end
