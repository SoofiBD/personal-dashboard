require "test_helper"

class PersonalFinance::TransactionTest < ActiveSupport::TestCase
  test "rejects an account owned by another dashboard user" do
    owner = User.create!(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")
    other_user = User.create!(name: "Other", currency: "TRY", time_zone: "Europe/Istanbul")
    account = PersonalFinance::Account.create!(user: other_user, name: "Other account", kind: :bank, opening_balance: 0)

    transaction = PersonalFinance::Transaction.new(user: owner, account: account, kind: :expense, amount: 100, occurred_on: Date.current)

    assert_not transaction.valid?
    assert_includes transaction.errors[:account], "is invalid"
  end

  test "requires a category with the same transaction kind" do
    owner = User.create!(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")
    account = PersonalFinance::Account.create!(user: owner, name: "Cash", kind: :cash, opening_balance: 0)
    income_category = PersonalFinance::Category.create!(user: owner, name: "Salary", kind: :income, color: "#2563EB")

    transaction = PersonalFinance::Transaction.new(user: owner, account: account, category: income_category, kind: :expense, amount: 100, occurred_on: Date.current)

    assert_not transaction.valid?
    assert_includes transaction.errors[:category], "is invalid"
  end

  test "search_notes scope returns matches case-insensitively" do
    owner = User.create!(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")
    account = PersonalFinance::Account.create!(user: owner, name: "Cash", kind: :cash, opening_balance: 0)
    category = PersonalFinance::Category.create!(user: owner, name: "Food", kind: :expense, color: "#2563EB")
    t1 = PersonalFinance::Transaction.create!(user: owner, account: account, category: category, kind: :expense, amount: 100, occurred_on: Date.current, note: "Grocery store buy")
    t2 = PersonalFinance::Transaction.create!(user: owner, account: account, category: category, kind: :expense, amount: 200, occurred_on: Date.current, note: "Dinner out")

    results = PersonalFinance::Transaction.search_notes("grocery")
    assert_includes results, t1
    assert_not_includes results, t2
  end

  test "search_notes treats LIKE wildcard characters as literal text" do
    owner = User.create!(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")
    account = PersonalFinance::Account.create!(user: owner, name: "Cash", kind: :cash, opening_balance: 0)
    category = PersonalFinance::Category.create!(user: owner, name: "Food", kind: :expense, color: "#2563EB")
    percent_note = PersonalFinance::Transaction.create!(user: owner, account: account, category: category, kind: :expense, amount: 100, occurred_on: Date.current, note: "100% rebate")
    underscore_note = PersonalFinance::Transaction.create!(user: owner, account: account, category: category, kind: :expense, amount: 200, occurred_on: Date.current, note: "item_code")
    non_matching_note = PersonalFinance::Transaction.create!(user: owner, account: account, category: category, kind: :expense, amount: 300, occurred_on: Date.current, note: "100x rebate itemXcode")

    assert_equal [percent_note], PersonalFinance::Transaction.search_notes("100%").to_a
    assert_equal [underscore_note], PersonalFinance::Transaction.search_notes("item_code").to_a
    assert_not_includes PersonalFinance::Transaction.search_notes("100%").to_a, non_matching_note
    assert_not_includes PersonalFinance::Transaction.search_notes("item_code").to_a, non_matching_note
  end
end
