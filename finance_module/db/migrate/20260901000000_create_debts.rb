class CreateDebts < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_debts, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.decimal :total_amount, null: false, precision: 14, scale: 2
      t.decimal :remaining_amount, null: false, precision: 14, scale: 2
      t.decimal :interest_rate, null: false, precision: 6, scale: 3, default: 0
      t.decimal :monthly_payment, null: false, precision: 14, scale: 2
      t.integer :remaining_installments, null: false
      t.date :next_payment_on
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    create_table :finance_debt_payments, id: :uuid do |t|
      t.references :debt, null: false, type: :uuid, foreign_key: {to_table: :finance_debts}
      t.decimal :amount, null: false, precision: 14, scale: 2
      t.date :paid_on, null: false
      t.timestamps
    end
    add_index :finance_debts, %i[user_id active]
  end
end
