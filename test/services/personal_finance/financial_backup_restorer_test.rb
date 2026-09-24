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

  test "restores version 2 dependent records without user ids" do
    user = User.create!(name: "Target", currency: "TRY", time_zone: "Europe/Istanbul")
    source_id = SecureRandom.uuid
    account_id = SecureRandom.uuid
    category_id = SecureRandom.uuid
    budget_id = SecureRandom.uuid
    transaction_id = SecureRandom.uuid
    tag_id = SecureRandom.uuid
    payload = {"metadata" => {"version" => 2}, "data" => {
      "accounts" => [{"id" => account_id, "user_id" => source_id, "name" => "Cash", "kind" => "cash", "opening_balance" => "0", "currency" => "TRY", "is_active" => true}],
      "categories" => [{"id" => category_id, "user_id" => source_id, "name" => "Food", "kind" => "expense", "color" => "#2563EB", "icon" => "circle", "sort_order" => 0}],
      "budget_periods" => [{"id" => budget_id, "user_id" => source_id, "starts_on" => "2026-09-01", "ends_on" => "2026-09-30", "planned_income" => "100"}],
      "transactions" => [{"id" => transaction_id, "user_id" => source_id, "financial_account_id" => account_id, "category_id" => category_id, "kind" => "expense", "amount" => "25", "occurred_on" => "2026-09-01"}],
      "tags" => [{"id" => tag_id, "user_id" => source_id, "name" => "Work"}],
      "budget_allocations" => [{"id" => SecureRandom.uuid, "budget_period_id" => budget_id, "category_id" => category_id, "planned_amount" => "100"}],
      "transaction_tags" => [{"id" => SecureRandom.uuid, "transaction_id" => transaction_id, "tag_id" => tag_id}]
    }}

    PersonalFinance::FinancialBackupRestorer.new(user, payload).call

    assert_equal 1, PersonalFinance::BudgetAllocation.joins(:budget_period).where(finance_budget_periods: {user_id: user.id}).count
    assert_equal ["Work"], PersonalFinance::Transaction.find(transaction_id).tags.pluck(:name)
  end
end
