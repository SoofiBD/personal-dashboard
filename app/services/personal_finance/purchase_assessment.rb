module PersonalFinance
  class PurchaseAssessment
    SCENARIO_DEFINITIONS = [
      {key: :cash, months: 0},
      {key: :installment_3, months: 3},
      {key: :installment_6, months: 6},
      {key: :installment_12, months: 12}
    ].freeze

    def initialize(plan)
      @plan = plan
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

    def monthly_free_cash
      monthly_income - monthly_expenses - active_goal_contributions
    end

    def available_cash
      PersonalFinance::Account.where(user_id: @plan.user_id, is_active: true).sum(&:current_balance)
    end

    def safety_buffer_after_purchase(down_payment = @plan.down_payment)
      available_cash - down_payment - monthly_expenses
    end

    def affects_goal?
      @plan.savings_goal.present? && @plan.savings_goal.remaining_amount.positive?
    end

    def status(down_payment = @plan.down_payment, monthly_cost = @plan.monthly_cost, affects_goal: affects_goal?)
      return :defer if monthly_free_cash - monthly_cost < 0 || safety_buffer_after_purchase(down_payment) < 0
      return :plan if monthly_cost.positive? || affects_goal
      :comfortable
    end

    def assumptions
      {
        monthly_income: monthly_income,
        monthly_expenses: monthly_expenses,
        active_goal_contributions: active_goal_contributions,
        monthly_free_cash: monthly_free_cash,
        available_cash: available_cash,
        savings_goal_remaining: @plan.savings_goal&.remaining_amount || 0
      }
    end

    def savings_goal_applied
      affects_goal? ? [@plan.savings_goal.remaining_amount.to_f, @plan.price.to_f].min : 0.0
    end

    def scenarios
      price = @plan.price.to_f
      base_down = @plan.down_payment.to_f
      list = SCENARIO_DEFINITIONS.map do |defn|
        if defn[:months].zero?
          down = price
          monthly = 0.0
        else
          down = base_down
          monthly = (price - base_down) / defn[:months]
        end
        build_scenario(defn[:key], scenario_label(defn[:key]), down, monthly, false)
      end

      if affects_goal?
        applied = savings_goal_applied
        remaining_after_goal = price - applied
        down = [base_down, remaining_after_goal].min
        monthly = (remaining_after_goal - down) / 12.0
        list << build_scenario(:savings_goal, scenario_label(:savings_goal), down, monthly, true)
      end

      list
    end

    private

    def build_scenario(key, label, down_payment, monthly_cost, affects_goal)
      {
        key: key,
        label: label,
        down_payment: down_payment.round(2),
        monthly_cost: monthly_cost.round(2),
        total: @plan.price.to_f.round(2),
        monthly_free_cash_after: (monthly_free_cash - monthly_cost).round(2),
        safety_buffer: safety_buffer_after_purchase(down_payment).round(2),
        status: status(down_payment, monthly_cost, affects_goal: affects_goal),
        affects_goal: affects_goal
      }
    end

    def scenario_label(key)
      I18n.t("backend.personal_finance.purchase_assessment.scenarios.#{key}", locale: @plan.user.locale)
    end

    def recent_transactions
      @plan.user.then { |user| PersonalFinance::Transaction.where(user_id: user.id, occurred_on: 3.months.ago.to_date..Date.current) }
    end
  end
end
