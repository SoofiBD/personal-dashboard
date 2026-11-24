module PersonalFinance
  class GoalContribution < ApplicationRecord
    self.table_name = "finance_goal_contributions"

    belongs_to :savings_goal, class_name: "PersonalFinance::SavingsGoal"
    belongs_to :linked_transaction, class_name: "PersonalFinance::Transaction",
      foreign_key: :transaction_id, optional: true

    validates :amount, numericality: {greater_than: 0}
    validates :contributed_on, presence: true
    validate :transaction_owned_by_goal_user
    validate :linked_transaction_is_savings_transfer
    validates :transaction_id, uniqueness: true, allow_nil: true

    private

    def transaction_owned_by_goal_user
      return unless linked_transaction && savings_goal
      errors.add(:linked_transaction, "is invalid") if linked_transaction.user_id != savings_goal.user_id
    end

    def linked_transaction_is_savings_transfer
      return unless linked_transaction
      unless linked_transaction.transfer? && linked_transaction.account.savings?
        errors.add(:linked_transaction, "must be a transfer to a savings account")
        return
      end
      errors.add(:amount, "must match the linked transfer") unless amount.to_d == linked_transaction.amount.to_d
    end
  end
end
