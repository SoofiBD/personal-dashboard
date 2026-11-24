module PersonalFinance
  class SavingsGoal < ApplicationRecord
    self.table_name = "finance_savings_goals"

    belongs_to :user, class_name: "::User"
    has_many :contributions, class_name: "PersonalFinance::GoalContribution", foreign_key: :savings_goal_id, dependent: :destroy

    enum :status, {active: "active", paused: "paused", completed: "completed", archived: "archived"}, validate: true
    validates :name, presence: true, length: {maximum: 100}
    validates :target_amount, numericality: {greater_than: 0}
    validates :starting_amount, :monthly_contribution, numericality: {greater_than_or_equal_to: 0}

    def saved_amount
      starting_amount + contributions.sum(:amount)
    end

    def remaining_amount
      [target_amount - saved_amount, 0].max
    end

    def estimated_months
      monthly_contribution.positive? ? (remaining_amount / monthly_contribution).ceil : nil
    end
  end
end
