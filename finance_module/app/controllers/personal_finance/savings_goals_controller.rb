module PersonalFinance
  class SavingsGoalsController < ApplicationController
    before_action :set_goal, only: %i[show edit update destroy]
    def index
      @savings_goals = owned(SavingsGoal).order(:status, :target_date)
    end

    def new
      @savings_goal = owned(SavingsGoal).new(status: "active")
    end

    def show
      @contributions = @savings_goal.contributions.includes(linked_transaction: :account).order(contributed_on: :desc, created_at: :desc)
      @contribution = @savings_goal.contributions.new(contributed_on: Date.current)
      @eligible_transfers = eligible_transfers
    end

    def edit
    end

    def create
      @savings_goal = owned(SavingsGoal).new(goal_params)
      save_or_render
    end

    def update
      @savings_goal.assign_attributes(goal_params)
      save_or_render
    end

    def destroy
      @savings_goal.destroy!
      redirect_to finance_savings_goals_path, notice: t("savings_goals.flash.deleted", default: "Goal deleted.")
    end

    private

    def set_goal
      @savings_goal = owned(SavingsGoal).find(params[:id])
    end

    def goal_params
      params.require(:savings_goal).permit(:name, :target_amount, :target_date, :starting_amount, :monthly_contribution, :status)
    end

    def save_or_render
      if @savings_goal.save
        redirect_to(finance_savings_goals_path, notice: t("savings_goals.flash.saved", default: "Goal saved."))
      else
        render((action_name == "update") ? :edit : :new, status: :unprocessable_entity)
      end
    end

    def eligible_transfers
      owned(Transaction).transfer.joins(:account).where(financial_accounts: {kind: "savings"}).where.not(id: GoalContribution.where.not(transaction_id: nil).select(:transaction_id)).order(occurred_on: :desc)
    end
  end
end
