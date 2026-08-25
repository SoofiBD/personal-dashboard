class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_subscriptions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :recurring_rule, type: :uuid, foreign_key: {to_table: :finance_recurring_rules}
      t.string :name, null: false
      t.decimal :amount, null: false, precision: 14, scale: 2
      t.string :billing_interval, null: false, default: "monthly"
      t.date :renewal_on
      t.date :last_used_on
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :finance_subscriptions, %i[user_id active]
  end
end
