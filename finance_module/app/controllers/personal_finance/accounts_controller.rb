module PersonalFinance
  class AccountsController < ApplicationController
    before_action :set_account, only: %i[edit update destroy]
    def index
      @accounts = owned(Account).order(:name).to_a
      @account_histories = Account.balance_histories(@accounts)
      balances = @account_histories.transform_values { |history| history.last[:balance] }
      converter = CurrencyConverter.new(current_panel_user)
      @converted_total = @accounts.sum { |account| converter.convert(balances[account], account.currency) || 0 }
      @unconverted_accounts = @accounts.reject { |account| converter.convert(balances[account], account.currency) }
      @net_worth_history = 6.times.map do |offset|
        month = Date.current.beginning_of_month - (5 - offset).months
        {month: month, balance: @account_histories.values.sum { |history| history.find { |point| point[:month] == month }[:balance] }}
      end
    end

    def new
      @account = owned(Account).new(kind: "bank")
    end

    def edit
    end

    def create
      @account = owned(Account).new(account_params)
      save_or_render
    end

    def update
      @account.assign_attributes(account_params)
      save_or_render
    end

    def destroy
      @account.destroy!
      redirect_to finance_accounts_path, notice: t("accounts.flash.deleted", default: "Account deleted.")
    end

    private

    def set_account
      @account = owned(Account).find(params[:id])
    end

    def account_params
      params.require(:account).permit(:name, :kind, :opening_balance, :is_active, :currency)
    end

    def save_or_render
      if @account.save
        redirect_to(finance_accounts_path, notice: t("accounts.flash.saved", default: "Account saved."))
      else
        render((action_name == "update") ? :edit : :new, status: :unprocessable_entity)
      end
    end
  end
end
