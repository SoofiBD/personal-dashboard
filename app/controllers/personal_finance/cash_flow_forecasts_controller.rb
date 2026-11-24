module PersonalFinance
  class CashFlowForecastsController < ApplicationController
    def show
      @forecast = CashFlowForecast.new(
        current_panel_user,
        months: forecast_months,
        baseline_income: forecast_amount(:baseline_income),
        baseline_expenses: forecast_amount(:baseline_expenses)
      )
      @projection = @forecast.projection
    end

    private

    def forecast_months
      [params.fetch(:months, 6).to_i, 3].max.clamp(3, 6)
    end

    def forecast_amount(key)
      return if params[key].blank?

      amount = params[key].to_s.tr(",", ".").to_f
      amount.negative? ? nil : amount
    end
  end
end
