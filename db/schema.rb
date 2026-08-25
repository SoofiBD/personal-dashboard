# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_09_01_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "finance_budget_allocations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "budget_period_id", null: false
    t.uuid "category_id", null: false
    t.decimal "planned_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_period_id", "category_id"], name: "idx_on_budget_period_id_category_id_093457c74c", unique: true
    t.index ["budget_period_id"], name: "index_finance_budget_allocations_on_budget_period_id"
    t.index ["category_id"], name: "index_finance_budget_allocations_on_category_id"
  end

  create_table "finance_budget_periods", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.decimal "planned_income", precision: 14, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "starts_on"], name: "index_finance_budget_periods_on_user_id_and_starts_on", unique: true
    t.index ["user_id"], name: "index_finance_budget_periods_on_user_id"
  end

  create_table "finance_budget_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.jsonb "allocation_data", default: [], null: false
    t.boolean "predefined", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_finance_budget_templates_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_finance_budget_templates_on_user_id"
  end

  create_table "finance_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "parent_id"
    t.string "name", null: false
    t.string "kind", null: false
    t.string "color", default: "#2563EB", null: false
    t.string "icon", default: "circle", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_finance_categories_on_parent_id"
    t.index ["user_id", "name"], name: "index_finance_categories_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_finance_categories_on_user_id"
  end

  create_table "finance_debt_payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "debt_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.date "paid_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["debt_id"], name: "index_finance_debt_payments_on_debt_id"
  end

  create_table "finance_debts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.decimal "total_amount", precision: 14, scale: 2, null: false
    t.decimal "remaining_amount", precision: 14, scale: 2, null: false
    t.decimal "interest_rate", precision: 6, scale: 3, default: "0.0", null: false
    t.decimal "monthly_payment", precision: 14, scale: 2, null: false
    t.integer "remaining_installments", null: false
    t.date "next_payment_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "active"], name: "index_finance_debts_on_user_id_and_active"
    t.index ["user_id"], name: "index_finance_debts_on_user_id"
  end

  create_table "finance_exchange_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "base_currency", limit: 3, null: false
    t.string "quote_currency", limit: 3, null: false
    t.decimal "rate", precision: 18, scale: 6, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "base_currency", "quote_currency"], name: "index_exchange_rates_on_user_and_currencies", unique: true
    t.index ["user_id"], name: "index_finance_exchange_rates_on_user_id"
  end

  create_table "finance_goal_contributions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "savings_goal_id", null: false
    t.uuid "transaction_id"
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.date "contributed_on", null: false
    t.string "note", limit: 500
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["savings_goal_id"], name: "index_finance_goal_contributions_on_savings_goal_id"
    t.index ["transaction_id"], name: "index_finance_goal_contributions_on_transaction_id"
  end

  create_table "finance_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "read_at", "created_at"], name: "idx_on_user_id_read_at_created_at_d9bdbdd28b"
    t.index ["user_id"], name: "index_finance_notifications_on_user_id"
  end

  create_table "finance_purchase_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "savings_goal_id"
    t.string "name", null: false
    t.decimal "price", precision: 14, scale: 2, null: false
    t.date "planned_on"
    t.decimal "down_payment", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "monthly_cost", precision: 14, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["savings_goal_id"], name: "index_finance_purchase_plans_on_savings_goal_id"
    t.index ["user_id"], name: "index_finance_purchase_plans_on_user_id"
  end

  create_table "finance_recurring_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "financial_account_id", null: false
    t.uuid "category_id"
    t.string "kind", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "note", limit: 500
    t.date "starts_on", null: false
    t.string "recurrence_interval", null: false
    t.date "recurrence_end_date"
    t.integer "recurrence_count"
    t.integer "generated_count", default: 1, null: false
    t.boolean "is_paused", default: false, null: false
    t.date "last_generated_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "stopped_at"
    t.index ["category_id"], name: "index_finance_recurring_rules_on_category_id"
    t.index ["financial_account_id"], name: "index_finance_recurring_rules_on_financial_account_id"
    t.index ["user_id", "is_paused"], name: "index_finance_recurring_rules_on_user_id_and_is_paused"
    t.index ["user_id"], name: "index_finance_recurring_rules_on_user_id"
    t.check_constraint "amount > 0::numeric", name: "finance_recurring_rule_amount_positive"
    t.check_constraint "recurrence_count IS NULL OR recurrence_count > 0", name: "finance_recurring_rule_count_positive"
  end

  create_table "finance_savings_goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.decimal "target_amount", precision: 14, scale: 2, null: false
    t.date "target_date"
    t.decimal "starting_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "monthly_contribution", precision: 14, scale: 2, default: "0.0", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_finance_savings_goals_on_user_id"
  end

  create_table "finance_subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "recurring_rule_id"
    t.string "name", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "billing_interval", default: "monthly", null: false
    t.date "renewal_on"
    t.date "last_used_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recurring_rule_id"], name: "index_finance_subscriptions_on_recurring_rule_id"
    t.index ["user_id", "active"], name: "index_finance_subscriptions_on_user_id_and_active"
    t.index ["user_id"], name: "index_finance_subscriptions_on_user_id"
  end

  create_table "finance_tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", limit: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "user_id, lower((name)::text)", name: "index_finance_tags_on_user_and_lower_name", unique: true
    t.index ["user_id"], name: "index_finance_tags_on_user_id"
  end

  create_table "finance_transaction_imports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "financial_account_id", null: false
    t.text "source_csv", null: false
    t.jsonb "column_mapping", default: {}, null: false
    t.jsonb "preview_rows", default: [], null: false
    t.integer "created_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.integer "error_count", default: 0, null: false
    t.datetime "imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["financial_account_id"], name: "index_finance_transaction_imports_on_financial_account_id"
    t.index ["user_id"], name: "index_finance_transaction_imports_on_user_id"
  end

  create_table "finance_transaction_tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "transaction_id", null: false
    t.uuid "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_finance_transaction_tags_on_tag_id"
    t.index ["transaction_id", "tag_id"], name: "index_finance_transaction_tags_on_transaction_id_and_tag_id", unique: true
    t.index ["transaction_id"], name: "index_finance_transaction_tags_on_transaction_id"
  end

  create_table "finance_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "financial_account_id", null: false
    t.uuid "category_id"
    t.string "kind", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.date "occurred_on", null: false
    t.string "note", limit: 500
    t.boolean "is_recurring", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "recurring_rule_id"
    t.index ["category_id"], name: "index_finance_transactions_on_category_id"
    t.index ["financial_account_id"], name: "index_finance_transactions_on_financial_account_id"
    t.index ["recurring_rule_id", "occurred_on"], name: "index_finance_transactions_on_rule_and_date", unique: true, where: "(recurring_rule_id IS NOT NULL)"
    t.index ["recurring_rule_id"], name: "index_finance_transactions_on_recurring_rule_id"
    t.index ["user_id", "occurred_on"], name: "index_finance_transactions_on_user_id_and_occurred_on"
    t.index ["user_id"], name: "index_finance_transactions_on_user_id"
    t.check_constraint "amount > 0::numeric", name: "finance_transaction_amount_positive"
  end

  create_table "financial_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.decimal "opening_balance", precision: 14, scale: 2, default: "0.0", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency", default: "TRY", null: false
    t.index ["currency"], name: "index_financial_accounts_on_currency"
    t.index ["user_id"], name: "index_financial_accounts_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "currency", limit: 3, default: "TRY", null: false
    t.string "time_zone", default: "Europe/Istanbul", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "onboarded_at"
    t.decimal "daily_spending_limit", precision: 14, scale: 2
    t.decimal "weekly_spending_limit", precision: 14, scale: 2
  end

  add_foreign_key "finance_budget_allocations", "finance_budget_periods", column: "budget_period_id"
  add_foreign_key "finance_budget_allocations", "finance_categories", column: "category_id"
  add_foreign_key "finance_budget_periods", "users"
  add_foreign_key "finance_budget_templates", "users"
  add_foreign_key "finance_categories", "finance_categories", column: "parent_id"
  add_foreign_key "finance_categories", "users"
  add_foreign_key "finance_debt_payments", "finance_debts", column: "debt_id"
  add_foreign_key "finance_debts", "users"
  add_foreign_key "finance_exchange_rates", "users"
  add_foreign_key "finance_goal_contributions", "finance_savings_goals", column: "savings_goal_id"
  add_foreign_key "finance_goal_contributions", "finance_transactions", column: "transaction_id"
  add_foreign_key "finance_notifications", "users"
  add_foreign_key "finance_purchase_plans", "finance_savings_goals", column: "savings_goal_id"
  add_foreign_key "finance_purchase_plans", "users"
  add_foreign_key "finance_recurring_rules", "finance_categories", column: "category_id"
  add_foreign_key "finance_recurring_rules", "financial_accounts"
  add_foreign_key "finance_recurring_rules", "users"
  add_foreign_key "finance_savings_goals", "users"
  add_foreign_key "finance_subscriptions", "finance_recurring_rules", column: "recurring_rule_id"
  add_foreign_key "finance_subscriptions", "users"
  add_foreign_key "finance_tags", "users"
  add_foreign_key "finance_transaction_imports", "financial_accounts"
  add_foreign_key "finance_transaction_imports", "users"
  add_foreign_key "finance_transaction_tags", "finance_tags", column: "tag_id"
  add_foreign_key "finance_transaction_tags", "finance_transactions", column: "transaction_id"
  add_foreign_key "finance_transactions", "finance_categories", column: "category_id"
  add_foreign_key "finance_transactions", "finance_recurring_rules", column: "recurring_rule_id"
  add_foreign_key "finance_transactions", "financial_accounts"
  add_foreign_key "finance_transactions", "users"
  add_foreign_key "financial_accounts", "users"
end
