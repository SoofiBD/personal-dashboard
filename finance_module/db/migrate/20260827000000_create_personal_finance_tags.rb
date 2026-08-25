class CreatePersonalFinanceTags < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_tags, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false, limit: 50
      t.timestamps
    end
    add_index :finance_tags, "user_id, lower(name)", unique: true, name: "index_finance_tags_on_user_and_lower_name"

    create_table :finance_transaction_tags, id: :uuid do |t|
      t.references :transaction, null: false, type: :uuid, foreign_key: {to_table: :finance_transactions}
      t.references :tag, null: false, type: :uuid, foreign_key: {to_table: :finance_tags}
      t.timestamps
    end
    add_index :finance_transaction_tags, %i[transaction_id tag_id], unique: true
  end
end
