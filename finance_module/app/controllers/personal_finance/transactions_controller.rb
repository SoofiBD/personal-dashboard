module PersonalFinance
  class TransactionsController < ApplicationController
    before_action :set_transaction, only: %i[edit update destroy]

    def index
      @transactions = owned(Transaction).includes(:account, :category).order(occurred_on: :desc, created_at: :desc)
    end

    def new
      @transaction = owned(Transaction).new(occurred_on: Date.current, kind: "expense")
    end

    def edit
    end

    def create
      @transaction = owned(Transaction).new(transaction_params)
      save_or_render
    end

    def update
      @transaction.assign_attributes(transaction_params)
      save_or_render
    end

    def destroy
      @transaction.destroy!
      redirect_to finance_transactions_path, notice: t("transactions.flash.deleted", default: "Transaction deleted.")
    end

    private

    def set_transaction
      @transaction = owned(Transaction).find(params[:id])
    end

    def transaction_params
      params.require(:transaction).permit(:financial_account_id, :category_id, :kind, :amount, :occurred_on, :note, :is_recurring)
    end

    def save_or_render
      if @transaction.save
        redirect_to(finance_transactions_path, notice: t("transactions.flash.saved", default: "Transaction saved."))
      else
        render((action_name == "update") ? :edit : :new, status: :unprocessable_entity)
      end
    end
  end
end
