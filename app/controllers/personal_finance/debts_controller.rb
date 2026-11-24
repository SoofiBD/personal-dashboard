module PersonalFinance
  class DebtsController < ApplicationController
    before_action :set_debt, only: %i[edit update destroy pay]
    def index
      @debts = owned(Debt).order(active: :desc, next_payment_on: :asc)
      @total_debt = @debts.select(&:active?).sum(&:remaining_amount)
      @upcoming = @debts.select { |debt| debt.active? && debt.next_payment_on && debt.next_payment_on <= Date.current + 30.days }
    end

    def new
      @debt = owned(Debt).new(active: true, next_payment_on: Date.current)
    end

    def create
      @debt = owned(Debt).new(debt_params)
      @debt.remaining_amount ||= @debt.total_amount
      save_or_render
    end

    def edit
    end

    def update
      @debt.assign_attributes(debt_params)
      save_or_render
    end

    def destroy
      @debt.destroy!
      redirect_to finance_debts_path, notice: I18n.t("backend.personal_finance.debts.deleted")
    end

    def pay
      @debt.payments.create!(amount: params[:amount].presence || @debt.monthly_payment, paid_on: params[:paid_on].presence || Date.current)
      redirect_to finance_debts_path, notice: I18n.t("backend.personal_finance.debts.payment_recorded")
    rescue ActiveRecord::RecordInvalid
      redirect_to finance_debts_path, alert: I18n.t("backend.personal_finance.debts.payment_failed")
    end

    private

    def set_debt
      @debt = owned(Debt).find(params[:id])
    end

    def debt_params
      params.require(:debt).permit(:name, :total_amount, :remaining_amount, :interest_rate, :monthly_payment, :remaining_installments, :next_payment_on, :active)
    end

    def save_or_render
      if @debt.save
        redirect_to(finance_debts_path, notice: I18n.t("backend.personal_finance.debts.saved"))
      else
        render((action_name == "update") ? :edit : :new, status: :unprocessable_entity)
      end
    end
  end
end
