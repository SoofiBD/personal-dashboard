module PersonalFinance
  class BudgetTemplatesController < ApplicationController
    before_action :ensure_predefined_templates
    before_action :set_template, only: %i[update destroy refresh]

    def index
      @templates = owned(BudgetTemplate).order(predefined: :desc, name: :asc)
    end

    def update
      if @template.predefined?
        redirect_to finance_budget_templates_path, alert: "Hazır şablonların adı değiştirilemez."
        return
      end

      @template.update!(template_params)
      redirect_to finance_budget_templates_path, notice: "Şablon adı güncellendi."
    rescue ActiveRecord::RecordInvalid
      redirect_to finance_budget_templates_path, alert: "Şablon adı güncellenemedi."
    end

    def destroy
      if @template.predefined?
        redirect_to finance_budget_templates_path, alert: "Hazır şablonlar silinemez."
      else
        @template.destroy!
        redirect_to finance_budget_templates_path, notice: "Şablon silindi."
      end
    end

    def refresh
      budget = owned(BudgetPeriod).find_by!(starts_on: Date.strptime(params[:month], "%Y-%m").beginning_of_month)
      BudgetTemplate.save_budget!(user: current_panel_user, budget: budget, name: @template.name)
      redirect_to finance_budget_templates_path, notice: "Şablon seçilen ayın bütçesiyle güncellendi."
    rescue ArgumentError, ActiveRecord::RecordNotFound
      redirect_to finance_budget_templates_path, alert: "Güncellenecek geçerli bir bütçe ayı seçin."
    end

    private

    def ensure_predefined_templates
      BudgetTemplate.ensure_predefined_for!(current_panel_user)
    end

    def set_template
      @template = owned(BudgetTemplate).find(params[:id])
    end

    def template_params
      params.require(:budget_template).permit(:name)
    end
  end
end
