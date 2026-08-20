module PersonalFinance
  class PurchasePlan < ApplicationRecord
    self.table_name = "finance_purchase_plans"

    belongs_to :user, class_name: "::User"
    belongs_to :savings_goal, class_name: "PersonalFinance::SavingsGoal", optional: true
    validates :name, presence: true, length: {maximum: 100}
    validates :price, numericality: {greater_than: 0}
    validates :down_payment, :monthly_cost, numericality: {greater_than_or_equal_to: 0}
    validate :goal_owned_by_user

    def assessment
      PersonalFinance::PurchaseAssessment.new(self)
    end

    private

    def goal_owned_by_user
      errors.add(:savings_goal, "is invalid") if savings_goal && savings_goal.user_id != user_id
    end
  end
end
