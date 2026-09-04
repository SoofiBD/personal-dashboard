require "csv"

module PersonalFinance
  class TransactionsController < ApplicationController
    before_action :set_transaction, only: %i[edit update destroy]
    before_action :set_transaction_import, only: %i[preview_import confirm_import]

    def index
      @filters = filter_params

      @transactions = filtered_transactions.order(occurred_on: :desc, created_at: :desc)
      @accounts = owned(Account).order(:name)
      @categories = owned(Category).order(:name)
      @tags = owned(Tag).order(:name)
      @filters_active = @filters[:q].present? ||
        @filters[:kind].present? ||
        @filters[:account_id].present? ||
        @filters[:from].present? ||
        @filters[:to].present? ||
        @filters[:category_id].any? ||
        @filters[:tag_id].present?

      respond_to do |format|
        format.html
        format.csv do
          send_data transactions_csv(@transactions),
            filename: transactions_csv_filename(@transactions),
            type: "text/csv; charset=utf-8"
        end
      end
    end

    def new
      @transaction = owned(Transaction).new(occurred_on: Date.current, kind: "expense")
    end

    def category_suggestion
      render json: {category_id: CategorySuggester.call(current_panel_user, params[:note])}
    end

    def import
      @transaction_import = owned(TransactionImport).new
      @accounts = owned(Account).where(is_active: true).order(:name)
    end

    def create_import
      upload = params[:csv_file]
      @transaction_import = owned(TransactionImport).new(financial_account_id: params[:financial_account_id])
      @accounts = owned(Account).where(is_active: true).order(:name)

      if upload.blank?
        @transaction_import.errors.add(:base, "Choose a CSV file to upload.")
        return render :import, status: :unprocessable_entity
      end
      if upload.size > 2.megabytes
        @transaction_import.errors.add(:base, "CSV files must be 2 MB or smaller.")
        return render :import, status: :unprocessable_entity
      end

      @transaction_import.source_csv = upload.read.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      unless @transaction_import.save
        return render :import, status: :unprocessable_entity
      end

      @headers = csv_headers(@transaction_import.source_csv)
      if @headers.empty?
        @transaction_import.destroy!
        @transaction_import = owned(TransactionImport).new
        @transaction_import.errors.add(:base, "The CSV file needs a header row.")
        return render :import, status: :unprocessable_entity
      end
      render :map_import
    end

    def preview_import
      @headers = csv_headers(@transaction_import.source_csv)
      parser = CsvTransactionImport.new(@transaction_import, import_mapping_params)
      parser.preview
      if parser.errors.any?
        parser.errors.each { |error| @transaction_import.errors.add(:base, error) }
        return render :map_import, status: :unprocessable_entity
      end

      @transaction_import.update!(column_mapping: import_mapping_params, preview_rows: parser.rows)
      @preview_rows = parser.rows
      render :preview_import
    end

    def confirm_import
      return redirect_to finance_transactions_path, alert: "This CSV import was already completed." if @transaction_import.imported?

      CsvTransactionImport.new(@transaction_import).confirm!
      render :import_summary
    end

    def edit
    end

    def create
      @transaction = owned(Transaction).new(transaction_params)
      @transaction.savings_goal_id = savings_goal_id
      create_transaction_and_rule
    end

    def update
      @transaction.assign_attributes(transaction_params)
      save_or_render
    end

    def destroy
      @transaction.destroy!
      redirect_to finance_transactions_path, notice: t("transactions.flash.deleted", default: "Transaction deleted.")
    end

    private

    def set_transaction
      @transaction = owned(Transaction).find(params[:id])
    end

    def set_transaction_import
      @transaction_import = owned(TransactionImport).find(params[:import_id])
    end

    def csv_headers(source)
      CSV.parse(source.delete_prefix("\uFEFF"), headers: true).headers.compact
    rescue CSV::MalformedCSVError
      []
    end

    def import_mapping_params
      params.require(:column_mapping).permit(:date, :amount, :type, :category, :note).to_h
    end

    def filter_params
      raw = params.permit(:q, :kind, :account_id, :from, :to, :tag_id, category_id: []).to_h.symbolize_keys
      raw[:category_id] = Array(raw[:category_id])
      raw
    end

    def parse_date(value)
      Date.strptime(value, "%Y-%m-%d")
    rescue ArgumentError, TypeError
      nil
    end

    def filtered_transactions
      scope = owned(Transaction).includes(:account, :category, :tags)
      scope = scope.search_notes(@filters[:q]) if @filters[:q].present?
      scope = scope.where(kind: @filters[:kind]) if @filters[:kind].present?
      scope = scope.where(financial_account_id: @filters[:account_id]) if @filters[:account_id].present?

      if @filters[:category_id].any?
        category_ids = owned(Category).where(id: @filters[:category_id]).flat_map(&:self_and_descendant_ids).uniq
        scope = scope.where(category_id: category_ids)
      end
      scope = scope.joins(:tags).where(finance_tags: {id: owned(Tag).where(id: @filters[:tag_id])}).distinct if @filters[:tag_id].present?

      from = parse_date(@filters[:from])
      to = parse_date(@filters[:to])
      if from && to
        scope.where(occurred_on: from..to)
      elsif from
        scope.where("finance_transactions.occurred_on >= ?", from)
      elsif to
        scope.where("finance_transactions.occurred_on <= ?", to)
      else
        scope
      end
    end

    def transactions_csv(transactions)
      "\uFEFF" + CSV.generate do |csv|
        csv << %w[date type amount category account tags note]
        transactions.each do |transaction|
          csv << [
            transaction.occurred_on.iso8601,
            transaction.kind,
            transaction.amount.to_s("F"),
            csv_safe(transaction.category&.name),
            csv_safe(transaction.account&.name),
            transaction.tags.order(:name).pluck(:name).join(", "),
            csv_safe(transaction.note)
          ]
        end
      end
    end

    def transactions_csv_filename(transactions)
      dates = transactions.pluck(:occurred_on)
      return "transactions_empty.csv" if dates.empty?

      "transactions_#{dates.min.strftime("%Y-%m")}_#{dates.max.strftime("%Y-%m")}.csv"
    end

    def csv_safe(value)
      value = value.to_s
      value.match?(/\A[=+\-@]/) ? "'#{value}" : value
    end

    def transaction_params
      params.require(:transaction).permit(:financial_account_id, :category_id, :kind, :amount, :occurred_on, :note, :is_recurring)
    end

    def recurrence_params
      params.require(:transaction).permit(:recurrence_interval, :recurrence_end_date, :recurrence_count)
    end

    def create_transaction_and_rule
      if @transaction.is_recurring?
        @transaction.assign_attributes(recurrence_params)
        ActiveRecord::Base.transaction do
          @transaction.save!
          rule = owned(RecurringRule).create!(rule_attributes_for(@transaction))
          @transaction.update!(recurring_rule: rule)
          sync_tags(@transaction)
          SpendingNotificationGenerator.call(@transaction)
        end
        redirect_to finance_transactions_path, notice: t("transactions.flash.saved", default: "Transaction saved.")
      else
        save_or_render
      end
    rescue ActiveRecord::RecordInvalid => error
      source = error.record
      source.errors.each { |attribute, message| @transaction.errors.add(attribute, message) } unless source.equal?(@transaction)
      render :new, status: :unprocessable_entity
    end

    def rule_attributes_for(transaction)
      recurrence = recurrence_params
      {
        financial_account_id: transaction.financial_account_id,
        category_id: transaction.category_id,
        kind: transaction.kind,
        amount: transaction.amount,
        note: transaction.note,
        starts_on: transaction.occurred_on,
        last_generated_on: transaction.occurred_on,
        recurrence_interval: recurrence[:recurrence_interval],
        recurrence_end_date: recurrence[:recurrence_end_date].presence,
        recurrence_count: recurrence[:recurrence_count].presence
      }
    end

    def save_or_render
      if @transaction.save
        sync_tags(@transaction)
        goal = create_goal_contribution(@transaction)
        SpendingNotificationGenerator.call(@transaction, goal: goal)
        redirect_to(finance_transactions_path, notice: t("transactions.flash.saved", default: "Transaction saved."))
      else
        render((action_name == "update") ? :edit : :new, status: :unprocessable_entity)
      end
    end

    def sync_tags(transaction)
      names = tag_names.split(",").map { |name| name.strip.gsub(/\s+/, " ") }.reject(&:blank?).uniq.first(12)
      tags = names.map do |name|
        owned(Tag).where("LOWER(name) = ?", name.downcase).first || owned(Tag).create!(name: name)
      end
      transaction.tags = tags
    end

    def tag_names
      params.dig(:transaction, :tag_names).to_s
    end

    def create_goal_contribution(transaction)
      return if savings_goal_id.blank?

      goal = owned(SavingsGoal).find(savings_goal_id)
      goal.contributions.create!(linked_transaction: transaction, amount: transaction.amount, contributed_on: transaction.occurred_on, note: transaction.note)
      goal
    end

    def savings_goal_id
      params.dig(:transaction, :savings_goal_id)
    end
  end
end
