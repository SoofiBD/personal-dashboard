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

    def import
      upload = params[:backup_file]
      raise FinancialBackupRestorer::InvalidBackup, "Select a JSON backup file" unless upload
      raise FinancialBackupRestorer::InvalidBackup, "Backup files must be 10 MB or smaller" if upload.size > 10.megabytes

      payload = JSON.parse(upload.read)
      FinancialBackupRestorer.new(current_panel_user, payload).call
      redirect_to finance_data_path, notice: "Financial backup restored."
    rescue JSON::ParserError, FinancialBackupRestorer::InvalidBackup, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      redirect_to finance_data_path, alert: "Backup could not be restored: #{error.message}"
    end

    private

    def csv_export(records)
      CSV.generate do |csv|
        csv << %w[table id attributes]
        records.each { |table, rows| rows.each { |row| csv << [csv_safe(table), row["id"], csv_safe(row.except("id").to_json)] } }
      end
    end

    def csv_safe(value)
      value = value.to_s
      value.match?(/\A[=+\-@]/) ? "'#{value}" : value
    end
  end
end
