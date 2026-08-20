module PersonalFinance
  class BudgetsController < ApplicationController
    before_action :set_budget

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
        @budget.update!(budget_params)
        Array(params[:allocations]).each do |allocation|
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
