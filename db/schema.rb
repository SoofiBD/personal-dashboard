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

ActiveRecord::Schema[7.2].define(version: 2026_09_10_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "document_assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "document_conversion_id", null: false
    t.string "filename", limit: 255, null: false
    t.string "content_type", limit: 100, null: false
    t.integer "byte_size", null: false
    t.integer "width", null: false
    t.integer "height", null: false
    t.integer "page_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_conversion_id", "filename"], name: "index_document_assets_on_document_conversion_id_and_filename", unique: true
    t.index ["document_conversion_id"], name: "index_document_assets_on_conversion_id"
    t.check_constraint "byte_size > 0", name: "document_assets_byte_size_positive"
    t.check_constraint "page_number > 0", name: "document_assets_page_number_positive"
    t.check_constraint "width > 0 AND height > 0", name: "document_assets_dimensions_positive"
  end

  create_table "document_conversions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "source_filename", limit: 255, null: false
    t.string "status", limit: 24, default: "pending", null: false
    t.text "custom_notes"
    t.text "markdown_content"
    t.jsonb "processing_stats", default: {}, null: false
    t.text "error_message"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "conversion_options", default: {}, null: false
    t.index ["user_id", "created_at"], name: "index_document_conversions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_document_conversions_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text])", name: "document_conversions_status_valid"
  end

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

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
    t.string "theme_preference", default: "system", null: false
    t.string "password_digest"
    t.integer "authentication_version", default: 0, null: false
    t.string "role", default: "owner", null: false
    t.string "email"
    t.string "locale", default: "tr", null: false
    t.text "mfa_secret"
    t.boolean "mfa_enabled", default: false, null: false
    t.datetime "mfa_confirmed_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "document_assets", "document_conversions"
  add_foreign_key "document_conversions", "users"
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
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
