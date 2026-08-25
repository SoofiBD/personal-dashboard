require "csv"

module PersonalFinance
  class DataController < ApplicationController
    TABLES = {accounts: Account, categories: Category, transactions: Transaction, budget_periods: BudgetPeriod, savings_goals: SavingsGoal, purchase_plans: PurchasePlan, recurring_rules: RecurringRule, subscriptions: Subscription, debts: Debt}.freeze

    def show
    end

    def export
      records = TABLES.transform_values { |model| model.where(user_id: current_panel_user.id).as_json }
      payload = {metadata: {version: 1, exported_at: Time.current.iso8601, record_counts: records.transform_values(&:size)}, data: records}
      respond_to do |format|
        format.json { send_data JSON.pretty_generate(payload), filename: "finance-backup-#{Date.current}.json", type: "application/json" }
        format.csv { send_data csv_export(records), filename: "finance-backup-#{Date.current}.csv", type: "text/csv" }
      end
    end

    private

    def csv_export(records)
      CSV.generate do |csv|
        csv << %w[table id attributes]
        records.each { |table, rows| rows.each { |row| csv << [table, row["id"], row.except("id").to_json] } }
      end
    end
  end
end
