module PersonalFinance
  class FinancialBackupRestorer
    TABLES = DataController::TABLES.freeze
    USER_OWNED_TABLES = (TABLES.keys - %i[budget_allocations goal_contributions debt_payments transaction_tags]).freeze
    RESTORE_ORDER = %i[
      accounts categories tags budget_templates exchange_rates budget_periods savings_goals
      purchase_plans debts recurring_rules transactions subscriptions budget_allocations
      goal_contributions debt_payments transaction_tags notifications
    ].freeze

    class InvalidBackup < StandardError; end

    def initialize(user, payload)
      @user = user
      @payload = payload
      @data = payload.fetch("data")
    rescue KeyError
      raise InvalidBackup, "Backup data is missing"
    end

    def call
      validate_payload!
      ActiveRecord::Base.transaction do
        RESTORE_ORDER.each { |table| restore_table(table) }
      end
    end

    private

    def validate_payload!
      raise InvalidBackup, "Unsupported backup version" unless [1, 2].include?(@payload.dig("metadata", "version"))
      raise InvalidBackup, "Backup data must be an object" unless @data.is_a?(Hash)

      rows.each do |row|
        raise InvalidBackup, "Backup records must be objects" unless row.is_a?(Hash)
        raise InvalidBackup, "Backup record is missing an id" if row["id"].blank?
      end
      source_user_rows = USER_OWNED_TABLES.flat_map { |table| table_rows(table) }
      raise InvalidBackup, "Backup record is missing its source user" if source_user_rows.any? { |row| row["user_id"].blank? }

      source_user_ids = source_user_rows.filter_map { |row| row["user_id"] }.uniq
      raise InvalidBackup, "Backup contains multiple users" unless source_user_ids.one?
    end

    def restore_table(table)
      model = TABLES.fetch(table)
      if table == :categories
        restore_categories(model)
      elsif table == :debt_payments
        restore_debt_payments(model)
      else
        table_rows(table).each { |attributes| restore_record(model, attributes) }
      end
    end

    def restore_categories(model)
      pending = table_rows(:categories).dup
      until pending.empty?
        ready, pending = pending.partition { |attributes| attributes["parent_id"].blank? || model.exists?(user: @user, id: attributes["parent_id"]) }
        raise InvalidBackup, "Category hierarchy is invalid" if ready.empty?

        ready.each { |attributes| restore_record(model, attributes) }
      end
    end

    def restore_record(model, attributes)
      record = scoped_records(model).find_or_initialize_by(id: attributes.fetch("id"))
      record.assign_attributes(attributes.except("id", "user_id", "created_at", "updated_at"))
      record.user = @user if record.has_attribute?(:user_id)
      record.save!
    end

    def restore_debt_payments(model)
      new_rows = []
      table_rows(:debt_payments).each do |attributes|
        existing = scoped_records(model).find_by(id: attributes.fetch("id"))
        if existing
          existing.assign_attributes(attributes.except("id", "user_id", "created_at", "updated_at"))
          existing.save!
        else
          new_rows << attributes.slice(*model.column_names)
        end
      end
      model.insert_all!(new_rows) unless new_rows.empty?
    end

    def rows
      RESTORE_ORDER.flat_map { |table| table_rows(table) }
    end

    def table_rows(table)
      value = @data[table.to_s] || @data[table]
      return [] if value.nil?

      raise InvalidBackup, "#{table} must be an array" unless value.is_a?(Array)

      value
    end

    def scoped_records(model)
      case model.name
      when "PersonalFinance::BudgetAllocation"
        model.joins(:budget_period).where(finance_budget_periods: {user_id: @user.id})
      when "PersonalFinance::GoalContribution"
        model.joins(:savings_goal).where(finance_savings_goals: {user_id: @user.id})
      when "PersonalFinance::DebtPayment"
        model.joins(:debt).where(finance_debts: {user_id: @user.id})
      when "PersonalFinance::TransactionTag"
        model.joins(:financial_transaction).where(finance_transactions: {user_id: @user.id})
      else
        model.where(user: @user)
      end
    end
  end
end
