class CreateSpendingNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_notifications, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :read_at
      t.timestamps
    end

    add_index :finance_notifications, %i[user_id read_at created_at]
    add_column :users, :daily_spending_limit, :decimal, precision: 14, scale: 2
    add_column :users, :weekly_spending_limit, :decimal, precision: 14, scale: 2
  end
end
