module PersonalFinance
  class BudgetsController < ApplicationController
    before_action :set_budget

    def show
      @allocations = @budget.allocations.includes(:category).order("finance_categories.name")
      @expense_categories = owned(Category).expense.order(:name)
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
      redirect_to finance_budget_path(@budget.starts_on.strftime("%Y-%m")), notice: "Budget saved."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
      @allocations = @budget.allocations.includes(:category)
      @expense_categories = owned(Category).expense.order(:name)
      render :show, status: :unprocessable_entity
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
