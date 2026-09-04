require "test_helper"

class PersonalFinance::FinancialBackupRestorerTest < ActiveSupport::TestCase
  test "restores exported records into the target user and preserves dependencies" do
    user = User.create!(name: "Target", currency: "TRY", time_zone: "Europe/Istanbul")
    source_id = SecureRandom.uuid
    account_id = SecureRandom.uuid
    category_id = SecureRandom.uuid
    payload = {"metadata" => {"version" => 1}, "data" => {
      "accounts" => [{"id" => account_id, "user_id" => source_id, "name" => "Cash", "kind" => "cash", "opening_balance" => "100", "currency" => "TRY", "is_active" => true}],
      "categories" => [{"id" => category_id, "user_id" => source_id, "name" => "Food", "kind" => "expense", "color" => "#2563EB", "icon" => "circle", "sort_order" => 0}],
      "transactions" => [{"id" => SecureRandom.uuid, "user_id" => source_id, "financial_account_id" => account_id, "category_id" => category_id, "kind" => "expense", "amount" => "25", "occurred_on" => Date.current.iso8601, "note" => "Restored"}]
    }}

    PersonalFinance::FinancialBackupRestorer.new(user, payload).call

    transaction = PersonalFinance::Transaction.find_by!(user: user, note: "Restored")
    assert_equal "Cash", transaction.account.name
    assert_equal "Food", transaction.category.name
  end

  test "rejects multi-user backups without writing records" do
    user = User.create!(name: "Target", currency: "TRY", time_zone: "Europe/Istanbul")
    payload = {"metadata" => {"version" => 1}, "data" => {"accounts" => [{"id" => SecureRandom.uuid, "user_id" => SecureRandom.uuid}, {"id" => SecureRandom.uuid, "user_id" => SecureRandom.uuid}]}}

    assert_raises(PersonalFinance::FinancialBackupRestorer::InvalidBackup) { PersonalFinance::FinancialBackupRestorer.new(user, payload).call }
    assert_empty PersonalFinance::Account.where(user: user)
  end
end
