module PersonalFinance
  class AccountsController < ApplicationController
    before_action :set_account, only: %i[edit update destroy]
    def index
      @accounts = owned(Account).order(:name)
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
      params.require(:account).permit(:name, :kind, :opening_balance, :is_active)
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
