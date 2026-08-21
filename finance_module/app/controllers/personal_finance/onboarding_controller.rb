module PersonalFinance
  class OnboardingController < ApplicationController
    skip_before_action :ensure_onboarding_completed

    def show
      @currency = current_panel_user.currency.presence || "TRY"
      @currencies = %w[TRY USD EUR GBP CHF CAD AUD JPY]
      @current_month = Date.current.strftime("%Y-%m")
      @current_month_label = I18n.l(Date.current, format: "%B %Y")
      @default_expense_categories = SeedDefaultCategories::DEFAULT_EXPENSE_CATEGORIES
      @default_income_categories = SeedDefaultCategories::DEFAULT_INCOME_CATEGORIES
    end

    def create
      ActiveRecord::Base.transaction do
        process_currency_and_income
        process_accounts
        saved_categories = process_categories
        process_budget(saved_categories)
        process_savings_goal
        current_panel_user.update!(onboarded_at: Time.current)
      end

      redirect_to finance_root_path, notice: I18n.t("onboarding.completed_notice", default: "Tebrikler! Finans modülü kurulumunuz tamamlandı.")
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = "#{I18n.t("common.errors_title", default: "Lütfen hataları düzeltin:")} #{e.message}"
      show
      render :show, status: :unprocessable_entity
    end

    def skip
      ActiveRecord::Base.transaction do
        SeedDefaultCategories.call(current_panel_user)
        BudgetPeriod.find_or_create_by!(user_id: current_panel_user.id, starts_on: Date.current.beginning_of_month) do |bp|
          bp.ends_on = Date.current.end_of_month
          bp.planned_income = 0
        end
        current_panel_user.update!(onboarded_at: Time.current)
      end

      redirect_to finance_root_path, notice: I18n.t("onboarding.skipped_notice", default: "Kurulum atlandı. İstediğiniz zaman bütçe ve kategorilerinizi düzenleyebilirsiniz.")
    end

    private

    def process_currency_and_income
      if params[:currency].present? && %w[TRY USD EUR GBP CHF CAD AUD JPY].include?(params[:currency].to_s.upcase)
        current_panel_user.update!(currency: params[:currency].to_s.upcase)
      end
    end

    def process_accounts
      return unless params[:accounts].is_a?(Array) || params[:accounts].is_a?(ActionController::Parameters)

      accounts_data = params[:accounts].is_a?(ActionController::Parameters) ? params[:accounts].values : params[:accounts]
      accounts_data.each do |acc|
        name = acc[:name].to_s.strip
        kind = acc[:kind].to_s.strip
        balance = acc[:opening_balance].to_s.tr(",", ".").to_f
        next if name.blank?

        current_panel_user.financial_accounts.create!(
          name: name,
          kind: kind.presence_in(%w[cash bank card savings]) || "cash",
          opening_balance: balance,
          is_active: true
        )
      end
    end

    def process_categories
      categories_param = params[:categories]
      if categories_param.blank?
        return SeedDefaultCategories.call(current_panel_user)
      end

      categories_data = categories_param.is_a?(ActionController::Parameters) ? categories_param.values : categories_param
      created = []

      categories_data.each_with_index do |cat, idx|
        next if cat[:enabled] == "0" || cat[:enabled] == false

        name = cat[:name].to_s.strip
        next if name.blank?

        category = current_panel_user.finance_categories.find_or_initialize_by(name: name)
        category.assign_attributes(
          kind: cat[:kind].presence_in(%w[expense income transfer]) || "expense",
          color: cat[:color].presence || "#3B82F6",
          icon: cat[:icon].presence || "circle",
          sort_order: cat[:sort_order].presence || (idx + 1)
        )
        category.save!
        created << category
      end

      # Also make sure default income categories exist if none were added
      if created.none? { |c| c.kind == "income" }
        SeedDefaultCategories::DEFAULT_INCOME_CATEGORIES.each do |inc_data|
          c = current_panel_user.finance_categories.find_or_initialize_by(name: inc_data[:name])
          c.assign_attributes(inc_data)
          c.save!
          created << c
        end
      end

      created
    end

    def process_budget(categories)
      planned_income = params[:planned_income].to_s.tr(",", ".").to_f
      period = current_panel_user.finance_budget_periods.find_or_initialize_by(starts_on: Date.current.beginning_of_month)
      period.ends_on = Date.current.end_of_month
      period.planned_income = [planned_income, 0].max
      period.save!

      allocations_param = params[:allocations]
      return unless allocations_param.present?

      allocations_data = allocations_param.is_a?(ActionController::Parameters) ? allocations_param.to_unsafe_h : allocations_param
      expense_categories = categories.select { |c| c.kind == "expense" }

      allocations_data.each do |cat_key, amount_str|
        amount = amount_str.to_s.tr(",", ".").to_f
        next unless amount.positive?

        # cat_key can be category id or name
        cat = expense_categories.find { |c| c.id.to_s == cat_key.to_s || c.name.to_s.downcase == cat_key.to_s.downcase }
        next unless cat

        allocation = period.allocations.find_or_initialize_by(category_id: cat.id)
        allocation.planned_amount = amount
        allocation.save!
      end
    end

    def process_savings_goal
      goal_param = params[:savings_goal]
      return if goal_param.blank?

      name = goal_param[:name].to_s.strip
      target_amount = goal_param[:target_amount].to_s.tr(",", ".").to_f
      return if name.blank? || target_amount <= 0

      current_panel_user.finance_savings_goals.create!(
        name: name,
        target_amount: target_amount,
        target_date: goal_param[:target_date].presence,
        starting_amount: goal_param[:starting_amount].to_s.tr(",", ".").to_f,
        monthly_contribution: goal_param[:monthly_contribution].to_s.tr(",", ".").to_f,
        status: "active"
      )
    end
  end
end
