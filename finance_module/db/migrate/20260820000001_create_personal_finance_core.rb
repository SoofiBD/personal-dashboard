class CreatePersonalFinanceCore < ActiveRecord::Migration[7.1]
  def change
    create_table :financial_accounts, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.decimal :opening_balance, null: false, precision: 14, scale: 2, default: 0
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end

    create_table :finance_categories, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true, foreign_key: true
      t.references :parent, type: :uuid, foreign_key: {to_table: :finance_categories}
      t.string :name, null: false
      t.string :kind, null: false
      t.string :color, null: false, default: "#2563EB"
      t.string :icon, null: false, default: "circle"
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end
    add_index :finance_categories, %i[user_id name], unique: true

    create_table :finance_transactions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true, foreign_key: true
      t.references :financial_account, null: false, type: :uuid, foreign_key: true
      t.references :category, type: :uuid, foreign_key: {to_table: :finance_categories}
      t.string :kind, null: false
      t.decimal :amount, null: false, precision: 14, scale: 2
      t.date :occurred_on, null: false
      t.string :note, limit: 500
      t.boolean :is_recurring, null: false, default: false
      t.timestamps
    end
    add_index :finance_transactions, %i[user_id occurred_on]
    add_check_constraint :finance_transactions, "amount > 0", name: "finance_transaction_amount_positive"
  end
end
