module PersonalFinance
  class FinancialBackupRestorer
    TABLES = DataController::TABLES.freeze
    RESTORE_ORDER = %i[accounts categories budget_periods savings_goals purchase_plans debts recurring_rules transactions subscriptions].freeze

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
      raise InvalidBackup, "Unsupported backup version" unless @payload.dig("metadata", "version") == 1
      raise InvalidBackup, "Backup data must be an object" unless @data.is_a?(Hash)

      rows.each do |row|
        raise InvalidBackup, "Backup records must be objects" unless row.is_a?(Hash)
        raise InvalidBackup, "Backup record is missing an id" if row["id"].blank?
        raise InvalidBackup, "Backup record is missing its source user" if row["user_id"].blank?
      end
      source_user_ids = rows.filter_map { |row| row["user_id"] }.uniq
      raise InvalidBackup, "Backup contains multiple users" unless source_user_ids.one?
    end

    def restore_table(table)
      model = TABLES.fetch(table)
      (table == :categories) ? restore_categories(model) : table_rows(table).each { |attributes| restore_record(model, attributes) }
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
      record = model.where(user: @user).find_or_initialize_by(id: attributes.fetch("id"))
      record.assign_attributes(attributes.except("id", "user_id", "created_at", "updated_at"))
      record.user = @user
      record.save!
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
  end
end
