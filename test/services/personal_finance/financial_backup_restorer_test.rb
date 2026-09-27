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

  test "rejects debt payments linked to another user without changing either account" do
    importer = User.create!(name: "Importer", currency: "TRY", time_zone: "Europe/Istanbul")
    victim = User.create!(name: "Victim", currency: "TRY", time_zone: "Europe/Istanbul")
    debt = PersonalFinance::Debt.create!(user: victim, name: "Private", total_amount: 200, remaining_amount: 200, monthly_payment: 50, remaining_installments: 4, next_payment_on: Date.current)
    account_id = SecureRandom.uuid
    payload = {"metadata" => {"version" => 2}, "data" => {
      "accounts" => [{"id" => account_id, "user_id" => SecureRandom.uuid, "name" => "Cash", "kind" => "cash", "opening_balance" => "0", "currency" => "TRY", "is_active" => true}],
      "debt_payments" => [{"id" => SecureRandom.uuid, "debt_id" => debt.id, "amount" => "50", "paid_on" => Date.current.iso8601}]
    }}

    assert_raises(PersonalFinance::FinancialBackupRestorer::InvalidBackup) { PersonalFinance::FinancialBackupRestorer.new(importer, payload).call }
    assert_equal 0, debt.payments.count
    assert_equal 200, debt.reload.remaining_amount
    assert_not PersonalFinance::Account.exists?(id: account_id)
  end

  test "restores owned debt payment history without double debit" do
    user = User.create!(name: "Target", currency: "TRY", time_zone: "Europe/Istanbul")
    debt_id = SecureRandom.uuid
    payload = {"metadata" => {"version" => 2}, "data" => {
      "debts" => [{"id" => debt_id, "user_id" => SecureRandom.uuid, "name" => "Loan", "total_amount" => "200", "remaining_amount" => "150", "monthly_payment" => "50", "remaining_installments" => 3, "next_payment_on" => Date.current.iso8601}],
      "debt_payments" => [{"id" => SecureRandom.uuid, "debt_id" => debt_id, "amount" => "50", "paid_on" => Date.current.iso8601}]
    }}

    PersonalFinance::FinancialBackupRestorer.new(user, payload).call

    debt = PersonalFinance::Debt.find_by!(id: debt_id, user: user)
    assert_equal 150, debt.remaining_amount
    assert_equal 1, debt.payments.count
  end

  test "rejects transaction tags linked to another user's transaction" do
    importer = User.create!(name: "Importer", currency: "TRY", time_zone: "Europe/Istanbul")
    victim = User.create!(name: "Victim", currency: "TRY", time_zone: "Europe/Istanbul")
    account = PersonalFinance::Account.create!(user: victim, name: "Victim cash", kind: "cash", opening_balance: 0)
    category = PersonalFinance::Category.create!(user: victim, name: "Food", kind: "expense", color: "#2563EB")
    transaction = PersonalFinance::Transaction.create!(user: victim, account: account, category: category, kind: "expense", amount: 20, occurred_on: Date.current)
    source_id = SecureRandom.uuid
    tag_id = SecureRandom.uuid
    payload = {"metadata" => {"version" => 2}, "data" => {
      "tags" => [{"id" => tag_id, "user_id" => source_id, "name" => "Imported"}],
      "transaction_tags" => [{"id" => SecureRandom.uuid, "transaction_id" => transaction.id, "tag_id" => tag_id}]
    }}

    assert_raises(PersonalFinance::FinancialBackupRestorer::InvalidBackup) { PersonalFinance::FinancialBackupRestorer.new(importer, payload).call }
    assert_empty transaction.tags.reload
    assert_not PersonalFinance::Tag.exists?(id: tag_id)
  end

  test "rejects a transaction linked to another user's recurring rule" do
    importer = User.create!(name: "Importer", currency: "TRY", time_zone: "Europe/Istanbul")
    victim = User.create!(name: "Victim", currency: "TRY", time_zone: "Europe/Istanbul")
    victim_account = PersonalFinance::Account.create!(user: victim, name: "Victim cash", kind: "cash", opening_balance: 0)
    rule = PersonalFinance::RecurringRule.create!(user: victim, account: victim_account, kind: "expense", amount: 10, starts_on: Date.current, last_generated_on: Date.current, recurrence_interval: "monthly")
    source_id = SecureRandom.uuid
    account_id = SecureRandom.uuid
    transaction_id = SecureRandom.uuid
    payload = {"metadata" => {"version" => 2}, "data" => {
      "accounts" => [{"id" => account_id, "user_id" => source_id, "name" => "Cash", "kind" => "cash", "opening_balance" => "0", "currency" => "TRY", "is_active" => true}],
      "transactions" => [{"id" => transaction_id, "user_id" => source_id, "financial_account_id" => account_id, "recurring_rule_id" => rule.id, "kind" => "expense", "amount" => "10", "occurred_on" => Date.current.iso8601}]
    }}

    assert_raises(PersonalFinance::FinancialBackupRestorer::InvalidBackup) { PersonalFinance::FinancialBackupRestorer.new(importer, payload).call }
    assert_not PersonalFinance::Transaction.exists?(id: transaction_id)
    assert_not PersonalFinance::Account.exists?(id: account_id)
    assert_empty rule.transactions
  end
end
