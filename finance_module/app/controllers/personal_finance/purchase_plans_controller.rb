module PersonalFinance
  class PurchasePlansController < ApplicationController
    before_action :set_plan, only: %i[show edit update destroy convert]
    def index
      @purchase_plans = owned(PurchasePlan).includes(:savings_goal).order(planned_on: :asc)
    end

    def show
      @assessment = @purchase_plan.assessment
      @accounts = owned(Account).order(:name)
      @expense_categories = owned(Category).expense.order(:name)
    end

    def new
      @purchase_plan = owned(PurchasePlan).new(planned_on: Date.current)
    end

    def edit
    end

    def create
      @purchase_plan = owned(PurchasePlan).new(plan_params)
      save_or_render
    end

    def update
      @purchase_plan.assign_attributes(plan_params)
      save_or_render
    end

    def destroy
      @purchase_plan.destroy!
      redirect_to finance_purchase_plans_path, notice: t("purchase_plans.flash.deleted", default: "Plan deleted.")
    end

    def convert
      account = owned(Account).find(params[:financial_account_id])
      category = params[:category_id].present? ? owned(Category).expense.find(params[:category_id]) : nil
      transaction = owned(Transaction).new(
        financial_account_id: account.id,
        category_id: category&.id,
        kind: "expense",
        amount: @purchase_plan.price,
        occurred_on: @purchase_plan.planned_on || Date.current,
        note: "Satın Alma: #{@purchase_plan.name}"
      )
      if transaction.save
        redirect_to finance_purchase_plan_path(@purchase_plan), notice: t("purchase_plans.flash.converted", default: "Plan bir işleme dönüştürüldü.")
      else
        redirect_to finance_purchase_plan_path(@purchase_plan), alert: transaction.errors.full_messages.to_sentence
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to finance_purchase_plan_path(@purchase_plan), alert: t("purchase_plans.flash.convert_invalid", default: "Geçersiz hesap veya kategori seçimi.")
    end

    private

    def set_plan
      @purchase_plan = owned(PurchasePlan).find(params[:id])
    end

    def plan_params
      params.require(:purchase_plan).permit(:name, :price, :planned_on, :down_payment, :monthly_cost, :savings_goal_id, :notes)
    end

    def save_or_render
      if @purchase_plan.save
        redirect_to(finance_purchase_plans_path, notice: t("purchase_plans.flash.saved", default: "Purchase plan saved."))
      else
        render((action_name == "update") ? :edit : :new, status: :unprocessable_entity)
      end
    end
  end
end
