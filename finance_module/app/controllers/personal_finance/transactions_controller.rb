module PersonalFinance
  class TransactionsController < ApplicationController
    before_action :set_transaction, only: %i[edit update destroy]

    def index
      @filters = filter_params

      scope = owned(Transaction).includes(:account, :category)

      scope = scope.search_notes(@filters[:q]) if @filters[:q].present?
      scope = scope.where(kind: @filters[:kind]) if @filters[:kind].present?
      scope = scope.where(financial_account_id: @filters[:account_id]) if @filters[:account_id].present?

      if @filters[:category_id].any?
        category_ids = owned(Category).where(id: @filters[:category_id]).flat_map(&:self_and_descendant_ids).uniq
        scope = scope.where(category_id: category_ids)
      end

      from = parse_date(@filters[:from])
      to = parse_date(@filters[:to])
      if from && to
        scope = scope.where(occurred_on: from..to)
      elsif from
        scope = scope.where("finance_transactions.occurred_on >= ?", from)
      elsif to
        scope = scope.where("finance_transactions.occurred_on <= ?", to)
      end

      @transactions = scope.order(occurred_on: :desc, created_at: :desc)
      @accounts = owned(Account).order(:name)
      @categories = owned(Category).order(:name)
      @filters_active = @filters[:q].present? ||
        @filters[:kind].present? ||
        @filters[:account_id].present? ||
        @filters[:from].present? ||
        @filters[:to].present? ||
        @filters[:category_id].any?
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

    def filter_params
      raw = params.permit(:q, :kind, :account_id, :from, :to, category_id: []).to_h.symbolize_keys
      raw[:category_id] = Array(raw[:category_id])
      raw
    end

    def parse_date(value)
      Date.strptime(value, "%Y-%m-%d")
    rescue ArgumentError, TypeError
      nil
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
