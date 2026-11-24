module PersonalFinance
  class CashFlowForecast
    attr_reader :months, :baseline_income, :baseline_expenses

    def initialize(user, months: 6, baseline_income: nil, baseline_expenses: nil)
      @user = user
      @months = [months.to_i, 3].max.clamp(3, 6)
      @baseline_income = baseline_income || historical_transactions.income.sum(:amount) / 3.0
      @baseline_expenses = baseline_expenses || historical_transactions.expense.sum(:amount) / 3.0
    end

    def starting_balance
      @starting_balance ||= Account.where(user: @user, is_active: true).sum(&:current_balance).to_f
    end

    def projection
      balance = starting_balance
      remaining_goals = active_goals.to_h { |goal| [goal.id, goal.remaining_amount.to_f] }

      future_months.map do |month|
        recurring_income, recurring_expenses = recurring_for(month)
        goal_contributions = goal_contributions_for(remaining_goals)
        purchase_commitments = purchase_commitments_for(month)
        net_change = baseline_income - baseline_expenses + recurring_income - recurring_expenses - goal_contributions - purchase_commitments
        balance += net_change

        {
          month: month,
          label: I18n.l(month, format: "%b %Y"),
          baseline_income: baseline_income.to_f,
          baseline_expenses: baseline_expenses.to_f,
          recurring_income: recurring_income,
          recurring_expenses: recurring_expenses,
          goal_contributions: goal_contributions,
          purchase_commitments: purchase_commitments,
          net_change: net_change,
          balance: balance
        }
      end
    end

    def active_goals
      @active_goals ||= SavingsGoal.where(user: @user, status: "active").to_a
    end

    def purchase_plans
      @purchase_plans ||= PurchasePlan.where(user: @user, planned_on: future_months.first..future_months.last.end_of_month).order(:planned_on).to_a
    end

    private

    def historical_transactions
      @historical_transactions ||= Transaction.where(user: @user, is_recurring: false, occurred_on: 3.months.ago.to_date..Date.current)
    end

    def future_months
      @future_months ||= months.times.map { |offset| Date.current.next_month.beginning_of_month + offset.months }
    end

    def recurring_for(month)
      income = 0.0
      expenses = 0.0
      RecurringRule.where(user: @user).active.find_each do |rule|
        occurrences_for(rule, month).each do
          income += rule.amount.to_f if rule.income?
          expenses += rule.amount.to_f if rule.expense?
        end
      end
      [income, expenses]
    end

    def occurrences_for(rule, month)
      date = rule.next_occurrence_on
      generated_count = rule.generated_count
      occurrences = []
      while date <= month.end_of_month && rule_can_occur?(rule, date, generated_count)
        occurrences << date if date >= month
        generated_count += 1
        date = rule.advance_date(date)
      end
      occurrences
    end

    def rule_can_occur?(rule, date, generated_count)
      (rule.recurrence_end_date.blank? || date <= rule.recurrence_end_date) &&
        (rule.recurrence_count.blank? || generated_count < rule.recurrence_count)
    end

    def goal_contributions_for(remaining_goals)
      active_goals.sum do |goal|
        amount = [goal.monthly_contribution.to_f, remaining_goals[goal.id]].min
        remaining_goals[goal.id] -= amount
        amount
      end
    end

    def purchase_commitments_for(month)
      purchase_plans.select { |plan| plan.planned_on.between?(month, month.end_of_month) }.sum { |plan| plan.price.to_f }
    end
  end
end
