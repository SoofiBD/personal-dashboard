module PersonalFinance
  class PurchaseAssessment
    def initialize(plan)
      @plan = plan
    end

    def monthly_free_cash
      monthly_income - monthly_expenses - active_goal_contributions
    end

    def safety_buffer_after_purchase
      available_cash - @plan.down_payment - monthly_expenses
    end

    def status
      return :defer if monthly_free_cash - @plan.monthly_cost < 0 || safety_buffer_after_purchase < 0
      return :plan if @plan.monthly_cost.positive? || affects_goal?
      :comfortable
    end

    private

    def recent_transactions
      @plan.user.then { |user| PersonalFinance::Transaction.where(user_id: user.id, occurred_on: 3.months.ago.to_date..Date.current) }
    end

    def monthly_income
      recent_transactions.income.sum(:amount) / 3.0
    end

    def monthly_expenses
      recent_transactions.expense.sum(:amount) / 3.0
    end

    def active_goal_contributions
      PersonalFinance::SavingsGoal.where(user_id: @plan.user_id, status: "active").sum(:monthly_contribution)
    end

    def available_cash
      PersonalFinance::Account.where(user_id: @plan.user_id, is_active: true).sum(&:current_balance)
    end

    def affects_goal?
      @plan.savings_goal.present? && @plan.savings_goal.remaining_amount.positive?
    end
  end
end
