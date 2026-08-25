class CreateRecurringTransactionRules < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_recurring_rules, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true, foreign_key: true
      t.references :financial_account, null: false, type: :uuid, foreign_key: true
      t.references :category, type: :uuid, foreign_key: {to_table: :finance_categories}
      t.string :kind, null: false
      t.decimal :amount, null: false, precision: 14, scale: 2
      t.string :note, limit: 500
      t.date :starts_on, null: false
      t.string :recurrence_interval, null: false
      t.date :recurrence_end_date
      t.integer :recurrence_count
      t.integer :generated_count, null: false, default: 1
      t.boolean :is_paused, null: false, default: false
      t.date :last_generated_on, null: false
      t.timestamps
    end
    add_check_constraint :finance_recurring_rules, "amount > 0", name: "finance_recurring_rule_amount_positive"
    add_check_constraint :finance_recurring_rules, "recurrence_count IS NULL OR recurrence_count > 0", name: "finance_recurring_rule_count_positive"
    add_index :finance_recurring_rules, %i[user_id is_paused]

    add_reference :finance_transactions, :recurring_rule, type: :uuid, foreign_key: {to_table: :finance_recurring_rules}
    add_index :finance_transactions, %i[recurring_rule_id occurred_on], unique: true, where: "recurring_rule_id IS NOT NULL", name: "index_finance_transactions_on_rule_and_date"
  end
end
