require "test_helper"

class PersonalFinance::CsvTransactionImportTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Import User", currency: "TRY", time_zone: "Europe/Istanbul")
    @account = PersonalFinance::Account.create!(user: @user, name: "Card", kind: :bank, opening_balance: 0)
    @category = PersonalFinance::Category.create!(user: @user, name: "Food", kind: :expense, color: "#EF4444")
  end

  test "previews valid rows and flags duplicates" do
    PersonalFinance::Transaction.create!(user: @user, account: @account, category: @category, kind: :expense, amount: 12.5, occurred_on: Date.new(2026, 8, 1), note: "Coffee")
    import = create_import("date,amount,type,category,note\n01.08.2026,\"12,50\",gider,Food,Coffee\n02.08.2026,\"1.234,56\",gider,Food,Lunch")

    parser = PersonalFinance::CsvTransactionImport.new(import, mapping)
    parser.preview

    assert_empty parser.errors
    assert_equal %w[duplicate ready], parser.rows.pluck("status")
    assert_equal "1234.56", parser.rows.second["amount"]
  end

  test "imports ready rows and reports skipped duplicates" do
    import = create_import("date,amount,type,category,note\n2026-08-02,25,expense,Food,Lunch")
    parser = PersonalFinance::CsvTransactionImport.new(import, mapping)
    parser.preview
    import.update!(column_mapping: mapping, preview_rows: parser.rows)

    PersonalFinance::CsvTransactionImport.new(import).confirm!

    assert_equal 1, import.reload.created_count
    assert_equal 1, PersonalFinance::Transaction.where(user: @user, note: "Lunch").count
  end

  test "rejects oversized CSV shapes before building preview rows" do
    source = ("date,amount\n" + (1..PersonalFinance::CsvTransactionImport::MAX_ROWS + 1).map { |index| "2026-08-01,#{index}" }.join("\n"))
    parser = PersonalFinance::CsvTransactionImport.new(create_import(source), mapping)

    parser.preview

    assert_includes parser.errors, "CSV files may contain at most 10000 rows."
    assert_empty parser.rows
  end

  private

  def create_import(source)
    PersonalFinance::TransactionImport.create!(user: @user, account: @account, source_csv: source)
  end

  def mapping
    {"date" => "date", "amount" => "amount", "type" => "type", "category" => "category", "note" => "note"}
  end
end
