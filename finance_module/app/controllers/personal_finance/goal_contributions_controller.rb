module PersonalFinance
  class GoalContributionsController < ApplicationController
    def create
      goal = owned(SavingsGoal).find(params[:savings_goal_id])
      contribution = goal.contributions.new(contribution_params)
      if contribution.save
        redirect_to finance_savings_goals_path, notice: "Contribution added."
      else
        redirect_to finance_savings_goals_path, alert: contribution.errors.full_messages.to_sentence
      end
    end
    private
    def contribution_params
      params.require(:goal_contribution).permit(:amount, :contributed_on, :note, :transaction_id)
    end
  end
end
