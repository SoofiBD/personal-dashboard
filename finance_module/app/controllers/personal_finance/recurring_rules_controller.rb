module PersonalFinance
  class RecurringRulesController < ApplicationController
    before_action :set_rule, only: %i[edit update pause resume destroy]

    def index
      RecurringTransactionGenerator.generate_due_for(current_panel_user)
      @recurring_rules = owned(RecurringRule).includes(:account, :category).order(is_paused: :asc, created_at: :desc)
    end

    def edit; end

    def update
      if @recurring_rule.update(rule_params)
        redirect_to finance_recurring_rules_path, notice: t("recurring_rules.flash.updated", default: "Recurring pattern updated. Past transactions were not changed.")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def pause
      @recurring_rule.update!(is_paused: true)
      redirect_to finance_recurring_rules_path, notice: t("recurring_rules.flash.paused", default: "Recurring pattern paused.")
    end

    def resume
      @recurring_rule.update!(is_paused: false)
      RecurringTransactionGenerator.generate_due_for_rule(@recurring_rule)
      redirect_to finance_recurring_rules_path, notice: t("recurring_rules.flash.resumed", default: "Recurring pattern resumed.")
    end

    def destroy
      @recurring_rule.update!(stopped_at: Time.current, is_paused: false)
      redirect_to finance_recurring_rules_path, notice: t("recurring_rules.flash.stopped", default: "Recurring pattern stopped. Existing transactions were kept.")
    end

    private

    def set_rule
      @recurring_rule = owned(RecurringRule).find(params[:id])
    end

    def rule_params
      params.require(:recurring_rule).permit(:recurrence_interval, :recurrence_end_date, :recurrence_count)
    end
  end
end
