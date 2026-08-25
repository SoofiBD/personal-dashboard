require "csv"

module PersonalFinance
  class CsvTransactionImport
    MAX_ROWS = 10_000
    MAX_COLUMNS = 100
    DATE_FORMATS = ["%Y-%m-%d", "%d.%m.%Y", "%d/%m/%Y", "%m/%d/%Y"].freeze
    TYPE_ALIASES = {"income" => "income", "gelir" => "income", "expense" => "expense", "gider" => "expense", "transfer" => "transfer"}.freeze

    attr_reader :import, :errors, :rows

    def initialize(import, mapping = import.column_mapping)
      @import = import
      @mapping = mapping.to_h.stringify_keys
      @errors = []
      @rows = []
    end

    def preview
      validate_mapping
      return self if errors.any?

      existing_keys = existing_duplicate_keys
      seen_keys = Set.new
      parsed = CSV.parse(import.source_csv.delete_prefix("\uFEFF"), headers: true)
      if parsed.headers.compact.length > MAX_COLUMNS
        errors << "CSV files may contain at most #{MAX_COLUMNS} columns."
        return self
      end
      if parsed.length > MAX_ROWS
        errors << "CSV files may contain at most #{MAX_ROWS} rows."
        return self
      end

      parsed.each_with_index do |csv_row, index|
        row = parse_row(csv_row, index + 2)
        key = duplicate_key(row)
        row["status"] = if row["error"].present?
          "error"
        elsif existing_keys.include?(key) || seen_keys.include?(key)
          "duplicate"
        else
          seen_keys << key
          "ready"
        end
        rows << row
      end
      self
    rescue CSV::MalformedCSVError => error
      errors << "CSV could not be read: #{error.message}"
      self
    end

    def confirm!
      created = skipped = failed = 0
      import.preview_rows.each do |row|
        if row["status"] == "duplicate"
          skipped += 1
          next
        end
        if row["status"] == "error"
          failed += 1
          next
        end

        if duplicate_exists?(row)
          skipped += 1
          next
        end

        Transaction.create!(
          user: import.user,
          account: import.account,
          category_id: row["category_id"].presence,
          kind: row["kind"],
          amount: row["amount"],
          occurred_on: row["occurred_on"],
          note: row["note"].presence
        )
        created += 1
      rescue ActiveRecord::RecordInvalid
        failed += 1
      end

      import.update!(created_count: created, skipped_count: skipped, error_count: failed, imported_at: Time.current)
    end

    private

    def validate_mapping
      %w[date amount].each { |field| errors << "Map a column for #{field}." if @mapping[field].blank? }
    end

    def parse_row(csv_row, line_number)
      kind = parse_kind(value_for(csv_row, "type"))
      occurred_on = parse_date(value_for(csv_row, "date"))
      amount = parse_amount(value_for(csv_row, "amount"))
      category = category_for(value_for(csv_row, "category"), kind)
      error = if occurred_on.nil?
        "Invalid date"
      elsif amount.nil? || amount <= 0
        "Invalid amount"
      elsif kind.nil?
        "Invalid type"
      elsif value_for(csv_row, "category").present? && category.nil?
        "Category not found for this type"
      end

      {
        "line" => line_number,
        "date" => occurred_on&.iso8601 || value_for(csv_row, "date"),
        "occurred_on" => occurred_on&.iso8601,
        "amount" => amount&.to_s("F"),
        "kind" => kind,
        "category" => category&.name || value_for(csv_row, "category"),
        "category_id" => category&.id,
        "note" => value_for(csv_row, "note"),
        "error" => error
      }
    end

    def value_for(csv_row, field)
      header = @mapping[field]
      header.present? ? csv_row[header].to_s.strip : ""
    end

    def parse_date(value)
      DATE_FORMATS.each do |format|
        return Date.strptime(value, format)
      rescue ArgumentError
        next
      end
      nil
    end

    def parse_amount(value)
      normalized = value.gsub(/[^0-9,.-]/, "")
      if normalized.include?(",") && normalized.include?(".")
        normalized = (normalized.rindex(",") > normalized.rindex(".")) ? normalized.delete(".").sub(",", ".") : normalized.delete(",")
      elsif normalized.include?(",")
        normalized = normalized.delete(".").sub(",", ".")
      end
      BigDecimal(normalized)
    rescue ArgumentError
      nil
    end

    def parse_kind(value)
      TYPE_ALIASES[value.to_s.downcase.presence || "expense"]
    end

    def category_for(name, kind)
      return if name.blank? || kind.nil?
      Category.where(user: import.user, kind: kind).where("LOWER(name) = ?", name.downcase).first
    end

    def duplicate_key(row)
      [row["occurred_on"], row["amount"], row["note"].to_s].join("|")
    end

    def existing_duplicate_keys
      Transaction.where(user: import.user).pluck(:occurred_on, :amount, :note).map { |date, amount, note| [date.iso8601, amount.to_s("F"), note.to_s].join("|") }.to_set
    end

    def duplicate_exists?(row)
      Transaction.exists?(user: import.user, occurred_on: row["occurred_on"], amount: row["amount"], note: row["note"].presence)
    end
  end
end
