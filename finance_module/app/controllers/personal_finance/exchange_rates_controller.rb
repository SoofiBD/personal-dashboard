module PersonalFinance
  class ExchangeRatesController < ApplicationController
    before_action :set_rate, only: %i[edit update destroy]

    def index
      @rates = owned(ExchangeRate).order(:base_currency, :quote_currency)
      @exchange_rate = owned(ExchangeRate).new(quote_currency: current_panel_user.currency)
    end

    def create
      @exchange_rate = owned(ExchangeRate).new(rate_params)
      save_or_render
    end

    def edit
    end

    def update
      @exchange_rate.assign_attributes(rate_params)
      save_or_render
    end

    def destroy
      @exchange_rate.destroy!
      redirect_to finance_exchange_rates_path, notice: "Kur silindi."
    end

    private

    def set_rate
      @exchange_rate = owned(ExchangeRate).find(params[:id])
    end

    def rate_params
      params.require(:exchange_rate).permit(:base_currency, :quote_currency, :rate)
    end

    def save_or_render
      if @exchange_rate.save
        redirect_to finance_exchange_rates_path, notice: "Kur kaydedildi."
      else
        @rates = owned(ExchangeRate).order(:base_currency, :quote_currency)
        render :index, status: :unprocessable_entity
      end
    end
  end
end
