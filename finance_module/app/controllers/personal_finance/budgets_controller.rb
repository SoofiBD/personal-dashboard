module PersonalFinance
  class BudgetsController < ApplicationController
    before_action :set_budget, only: %i[show update currency]

    SUPPORTED_CURRENCIES = %w[TRY USD EUR GBP].freeze

    def show
      @allocations = @budget.allocations.includes(:category).order("finance_categories.name")
      @expense_categories = owned(Category).expense.includes(:parent, :children).order(:sort_order, :name)
      month = @budget.starts_on..@budget.ends_on
      category_spending = owned(Transaction).expense.during(month).group(:category_id).sum(:amount)
      @category_current_spent = {}
      @expense_categories.each do |cat|
        child_ids = cat.children.map(&:id)
        @category_current_spent[cat.id] = category_spending[cat.id].to_f + child_ids.sum { |cid| category_spending[cid].to_f }
      end
    end

    def update
      BudgetPeriod.transaction do
        allocations_data = Array(params[:allocations])
        total_planned = allocations_data.sum { |a| a[:planned_amount].to_f }

        @budget.update!(planned_income: total_planned)
        allocations_data.each do |allocation|
          category = owned(Category).expense.find(allocation[:category_id])
          record = @budget.allocations.find_or_initialize_by(category: category)
          record.update!(planned_amount: allocation[:planned_amount])
        end
      end
      redirect_to finance_budget_path(@budget.starts_on.strftime("%Y-%m")), notice: t("budgets.flash.saved", default: "Budget saved.")
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
      @allocations = @budget.allocations.includes(:category)
      @expense_categories = owned(Category).expense.order(:name)
      render :show, status: :unprocessable_entity
    end

    def currency
      currency = params[:currency].to_s.upcase
      unless SUPPORTED_CURRENCIES.include?(currency)
        redirect_to finance_budget_path(@budget.starts_on.strftime("%Y-%m")), alert: t("budgets.flash.invalid_currency", default: "Choose a supported currency.")
        return
      end

      current_panel_user.update!(currency: currency)
      redirect_to finance_budget_path(@budget.starts_on.strftime("%Y-%m")), notice: t("budgets.flash.currency_changed", currency: currency, default: "Display currency changed to #{currency}. Amounts were not converted.")
    end

    def year
      @year = params[:year].to_i
      raise ActiveRecord::RecordNotFound unless @year > 0 && @year < 2100

      year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

      # Load existing budget periods for this year (don't create missing ones here)
      @budgets_by_month = {}
      owned(BudgetPeriod).where(starts_on: year_range).each do |bp|
        @budgets_by_month[bp.starts_on.month] = bp
      end

      # Build 12-month data
      @months = (1..12).map do |month|
        date = Date.new(@year, month, 1)
        budget = @budgets_by_month[month]
        planned_income = budget&.planned_income.to_f
        planned_spending = budget&.planned_spending.to_f
        actual_income = owned(Transaction).income.during(date.beginning_of_month..date.end_of_month).sum(:amount).to_f
        actual_expense = budget ? budget.actual_spending : owned(Transaction).expense.during(date.beginning_of_month..date.end_of_month).sum(:amount).to_f
        {
          month: month,
          date: date,
          label: l(date, format: "%b"),
          full_label: l(date, format: "%B %Y"),
          has_budget: budget.present?,
          budget: budget,
          planned_income: planned_income,
          actual_income: actual_income,
          planned_spending: planned_spending,
          actual_expense: actual_expense,
          net: actual_income - actual_expense
        }
      end

      # Yearly totals
      @yearly = {
        planned_income: @months.sum { |m| m[:planned_income] },
        actual_income: @months.sum { |m| m[:actual_income] },
        planned_spending: @months.sum { |m| m[:planned_spending] },
        actual_expense: @months.sum { |m| m[:actual_expense] }
      }
      @yearly[:net] = @yearly[:actual_income] - @yearly[:actual_expense]

      # Category-level yearly aggregation
      @expense_categories = owned(Category).expense.includes(:parent, :children).order(:sort_order, :name)
      year_expenses = owned(Transaction).expense.where(occurred_on: year_range)
      year_spending_by_cat = year_expenses.group(:category_id).sum(:amount)

      # Yearly planned by category (sum across all allocations in the year)
      year_planned_by_cat = BudgetAllocation.joins(:budget_period)
        .where(budget_period_id: @budgets_by_month.values.map(&:id))
        .group(:category_id)
        .sum(:planned_amount)

      @category_yearly = @expense_categories.filter_map do |cat|
        planned = year_planned_by_cat[cat.id].to_f
        spent = year_spending_by_cat[cat.id].to_f
        # Include children in actual spending
        child_ids = cat.children.map(&:id)
        spent += child_ids.sum { |cid| year_spending_by_cat[cid].to_f }
        next if planned.zero? && spent.zero? && cat.children.any?

        {
          id: cat.id,
          name: cat.name,
          color: cat.color.presence || "#3B82F6",
          planned: planned,
          spent: spent,
          remaining: planned - spent,
          is_over: spent > planned && planned.positive?,
          percent: planned.positive? ? [(spent / planned * 100).round, 999].min : 0
        }
      end
    end

    private

    def set_budget
      month = Date.strptime(params[:month], "%Y-%m").beginning_of_month
      @budget = owned(BudgetPeriod).find_or_create_by!(starts_on: month) { |budget| budget.ends_on = month.end_of_month }
    rescue ArgumentError
      raise ActiveRecord::RecordNotFound
    end

    def budget_params
      params.require(:budget_period).permit(:planned_income)
    end
  end
end
