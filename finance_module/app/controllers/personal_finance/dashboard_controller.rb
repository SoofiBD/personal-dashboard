module PersonalFinance
  class DashboardController < ApplicationController
    def show
      month = Date.current.all_month
      @income = owned(Transaction).income.during(month).sum(:amount)
      @expenses = owned(Transaction).expense.during(month).sum(:amount)
      @budget = owned(BudgetPeriod).find_by(starts_on: month.begin)
      @goals = owned(SavingsGoal).active.order(:target_date).limit(3)
      @recent_transactions = owned(Transaction).includes(:category).order(occurred_on: :desc, created_at: :desc).limit(8)
      @monthly_cash_flow = cash_flow_for_last_six_months
    end

    private

    def cash_flow_for_last_six_months
      5.downto(0).map do |months_ago|
        period = months_ago.months.ago.to_date.all_month
        transactions = owned(Transaction).during(period)
        { label: I18n.l(period.begin, format: "%b"), income: transactions.income.sum(:amount), expenses: transactions.expense.sum(:amount) }
      end
    end
  end
end
