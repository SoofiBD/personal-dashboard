require "csv"

module PersonalFinance
  class DataController < ApplicationController
    TABLES = {
      accounts: Account,
      categories: Category,
      tags: Tag,
      budget_templates: BudgetTemplate,
      exchange_rates: ExchangeRate,
      budget_periods: BudgetPeriod,
      savings_goals: SavingsGoal,
      purchase_plans: PurchasePlan,
      debts: Debt,
      recurring_rules: RecurringRule,
      transactions: Transaction,
      subscriptions: Subscription,
      budget_allocations: BudgetAllocation,
      goal_contributions: GoalContribution,
      debt_payments: DebtPayment,
      transaction_tags: TransactionTag,
      notifications: Notification
    }.freeze

    def show
    end

    def export
      audit_security_event("financial_data_exported", format: request.format.symbol)
      records = TABLES.keys.to_h { |table| [table, export_scope(table).as_json] }
      payload = {metadata: {version: 2, exported_at: Time.current.iso8601, record_counts: records.transform_values(&:size)}, data: records}
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
      audit_security_event("financial_data_imported", bytes: upload.size)
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

    def export_scope(table)
      case table
      when :budget_allocations then BudgetAllocation.joins(:budget_period).where(finance_budget_periods: {user_id: current_panel_user.id})
      when :goal_contributions then GoalContribution.joins(:savings_goal).where(finance_savings_goals: {user_id: current_panel_user.id})
      when :debt_payments then DebtPayment.joins(:debt).where(finance_debts: {user_id: current_panel_user.id})
      when :transaction_tags then TransactionTag.joins(:financial_transaction).where(finance_transactions: {user_id: current_panel_user.id})
      else TABLES.fetch(table).where(user_id: current_panel_user.id)
      end
    end

    def csv_safe(value)
      value = value.to_s
      value.match?(/\A[=+\-@]/) ? "'#{value}" : value
    end
  end
end
