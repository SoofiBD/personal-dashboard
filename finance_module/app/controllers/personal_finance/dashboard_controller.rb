module PersonalFinance
  class DashboardController < ApplicationController
    def show
      RecurringTransactionGenerator.generate_due_for(current_panel_user)
      month = Date.current.all_month
      @income = owned(Transaction).income.during(month).sum(:amount)
      @expenses = owned(Transaction).expense.during(month).sum(:amount)
      converter = CurrencyConverter.new(current_panel_user)
      @accounts_with_balances = owned(Account).where(is_active: true).left_joins(:transactions).group("financial_accounts.id").select("financial_accounts.*, COALESCE(SUM(CASE WHEN finance_transactions.kind = 'income' THEN finance_transactions.amount WHEN finance_transactions.kind = 'expense' THEN -finance_transactions.amount ELSE 0 END), 0) AS transaction_balance")
      @total_balance = @accounts_with_balances.sum { |account| converter.convert(account.opening_balance + account.transaction_balance, account.currency) || 0 }
      @unconverted_balance_accounts = @accounts_with_balances.reject { |account| converter.convert(account.opening_balance + account.transaction_balance, account.currency) }
      @budget = owned(BudgetPeriod).includes(allocations: {category: %i[parent children]}).find_by(starts_on: month.begin)
      @goals = owned(SavingsGoal).active.order(:target_date).limit(3)
      @recent_transactions = owned(Transaction).includes(:category).order(occurred_on: :desc, created_at: :desc).limit(8)
      @unread_notifications = owned(Notification).unread.recent_first.limit(3)
      @total_debt = owned(Debt).where(active: true).sum(:remaining_amount)
      @financial_health = FinancialHealthScore.new(current_panel_user)
      @financial_health_trend = FinancialHealthScore.trend(current_panel_user)
      @monthly_cash_flow = cash_flow_for_last_six_months
      prepare_budget_data(month) if @budget
    end

    private

    def prepare_budget_data(month)
      category_spending_map = owned(Transaction).expense.during(month).group(:category_id).sum(:amount)

      @budget_allocations_data = @budget.allocations.select { |a| a.category.present? && a.planned_amount.to_f.positive? }.map do |allocation|
        cat = allocation.category
        child_ids = cat.children.map(&:id)
        spent = category_spending_map[cat.id].to_f + child_ids.sum { |cid| category_spending_map[cid].to_f }
        planned = allocation.planned_amount.to_f
        remaining = planned - spent
        percent = planned.positive? ? [(spent / planned * 100).round, 100].min : 0
        raw_percent = planned.positive? ? (spent / planned * 100).round : 0

        {
          id: cat.id,
          name: cat.full_name,
          short_name: cat.name,
          parent_name: cat.parent&.name,
          color: cat.color.presence || "#3B82F6",
          planned: planned,
          spent: spent,
          remaining: remaining,
          percent: percent,
          raw_percent: raw_percent,
          is_over: remaining.negative?
        }
      end.sort_by { |item| [item[:is_over] ? 0 : 1, -item[:spent]] }
    end

    def cash_flow_for_last_six_months
      first_month = 5.months.ago.to_date.beginning_of_month
      totals = owned(Transaction).during(first_month..Date.current.end_of_month).group("DATE_TRUNC('month', occurred_on)").pluck(
        Arel.sql("DATE_TRUNC('month', occurred_on)"),
        Arel.sql("COALESCE(SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END), 0)"),
        Arel.sql("COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount ELSE 0 END), 0)")
      ).to_h { |date, income, expenses| [date.to_date.beginning_of_month, {income: income, expenses: expenses}] }

      6.times.map do |offset|
        month = first_month + offset.months
        values = totals.fetch(month, {income: 0, expenses: 0})
        {label: I18n.l(month, format: "%b"), **values}
      end
    end
  end
end
