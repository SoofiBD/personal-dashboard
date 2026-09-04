module PersonalFinance
  class SubscriptionsController < ApplicationController
    before_action :set_subscription, only: %i[edit update destroy]

    def index
      @subscriptions = owned(Subscription).includes(:recurring_rule).order(active: :desc, renewal_on: :asc, name: :asc)
      @monthly_total = @subscriptions.active.sum(&:monthly_cost)
      @yearly_total = @subscriptions.active.sum(&:yearly_cost)
      @upcoming_subscriptions = @subscriptions.active.select(&:upcoming_renewal?)
    end

    def new
      @subscription = owned(Subscription).new(billing_interval: "monthly", active: true)
      load_recurring_rules
    end

    def create
      @subscription = owned(Subscription).new(subscription_params)
      if @subscription.save
        redirect_to finance_subscriptions_path, notice: I18n.t("backend.personal_finance.subscriptions.saved")
      else
        load_recurring_rules
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_recurring_rules
    end

    def update
      if @subscription.update(subscription_params)
        redirect_to finance_subscriptions_path, notice: I18n.t("backend.personal_finance.subscriptions.updated")
      else
        load_recurring_rules
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @subscription.destroy!
      redirect_to finance_subscriptions_path, notice: I18n.t("backend.personal_finance.subscriptions.deleted")
    end

    private

    def set_subscription
      @subscription = owned(Subscription).find(params[:id])
    end

    def load_recurring_rules
      @recurring_rules = owned(RecurringRule).active.expense.order(:note, :amount)
    end

    def subscription_params
      params.require(:subscription).permit(:name, :amount, :billing_interval, :renewal_on, :last_used_on, :active, :recurring_rule_id)
    end
  end
end
