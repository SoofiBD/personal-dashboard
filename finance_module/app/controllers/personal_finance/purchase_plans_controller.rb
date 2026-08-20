module PersonalFinance
  class PurchasePlansController < ApplicationController
    before_action :set_plan, only: %i[edit update destroy]
    def index
      @purchase_plans = owned(PurchasePlan).includes(:savings_goal).order(planned_on: :asc)
    end
    def new
      @purchase_plan = owned(PurchasePlan).new(planned_on: Date.current)
    end
    def edit; end
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
      redirect_to finance_purchase_plans_path, notice: "Plan deleted."
    end
    private
    def set_plan
      @purchase_plan = owned(PurchasePlan).find(params[:id])
    end
    def plan_params
      params.require(:purchase_plan).permit(:name, :price, :planned_on, :down_payment, :monthly_cost, :savings_goal_id, :notes)
    end
    def save_or_render
      @purchase_plan.save ? redirect_to(finance_purchase_plans_path, notice: "Purchase plan saved.") : render(action_name == "update" ? :edit : :new, status: :unprocessable_entity)
    end
  end
end
