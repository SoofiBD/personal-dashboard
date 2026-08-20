module PersonalFinance
  class GoalContribution < ApplicationRecord
    self.table_name = "finance_goal_contributions"

    belongs_to :savings_goal, class_name: "PersonalFinance::SavingsGoal"
    belongs_to :transaction, class_name: "PersonalFinance::Transaction", optional: true
    validates :amount, numericality: { greater_than: 0 }
    validates :contributed_on, presence: true
    validate :transaction_owned_by_goal_user

    private

    def transaction_owned_by_goal_user
      return unless transaction && savings_goal
      errors.add(:transaction, "is invalid") if transaction.user_id != savings_goal.user_id
    end
  end
end
