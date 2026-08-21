module PersonalFinance
  class CopyPreviousBudget
    def initialize(budget_period)
      @budget_period = budget_period
    end

    def call
      previous = previous_budget_period
      return false unless previous

      BudgetPeriod.transaction do
        @budget_period.update!(planned_income: previous.planned_income.to_f)
        previous.allocations.each do |allocation|
          next unless allocation.category.user_id == @budget_period.user_id
          @budget_period.allocations.find_or_initialize_by(category: allocation.category).update!(
            planned_amount: allocation.planned_amount
          )
        end
      end
      true
    end

    private

    def previous_budget_period
      BudgetPeriod.where(user_id: @budget_period.user_id)
        .where("starts_on < ?", @budget_period.starts_on)
        .order(starts_on: :desc).first
    end
  end
end
