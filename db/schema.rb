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

ActiveRecord::Schema[7.1].define(version: 2026_08_20_000002) do
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
    t.index ["category_id"], name: "index_finance_transactions_on_category_id"
    t.index ["financial_account_id"], name: "index_finance_transactions_on_financial_account_id"
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
    t.index ["user_id"], name: "index_financial_accounts_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "currency", limit: 3, default: "TRY", null: false
    t.string "time_zone", default: "Europe/Istanbul", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "finance_budget_allocations", "finance_budget_periods", column: "budget_period_id"
  add_foreign_key "finance_budget_allocations", "finance_categories", column: "category_id"
  add_foreign_key "finance_budget_periods", "users"
  add_foreign_key "finance_categories", "finance_categories", column: "parent_id"
  add_foreign_key "finance_categories", "users"
  add_foreign_key "finance_goal_contributions", "finance_savings_goals", column: "savings_goal_id"
  add_foreign_key "finance_goal_contributions", "finance_transactions", column: "transaction_id"
  add_foreign_key "finance_purchase_plans", "finance_savings_goals", column: "savings_goal_id"
  add_foreign_key "finance_purchase_plans", "users"
  add_foreign_key "finance_savings_goals", "users"
  add_foreign_key "finance_transactions", "finance_categories", column: "category_id"
  add_foreign_key "finance_transactions", "financial_accounts"
  add_foreign_key "finance_transactions", "users"
  add_foreign_key "financial_accounts", "users"
end
