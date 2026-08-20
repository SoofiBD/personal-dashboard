module PersonalFinance
  class GoalContribution < ApplicationRecord
    self.table_name = "finance_goal_contributions"

    belongs_to :savings_goal, class_name: "PersonalFinance::SavingsGoal"
    belongs_to :linked_transaction, class_name: "PersonalFinance::Transaction",
      foreign_key: :transaction_id, optional: true

    validates :amount, numericality: {greater_than: 0}
    validates :contributed_on, presence: true
    validate :transaction_owned_by_goal_user

    private

    def transaction_owned_by_goal_user
      return unless linked_transaction && savings_goal
      errors.add(:linked_transaction, "is invalid") if linked_transaction.user_id != savings_goal.user_id
    end
  end
end
