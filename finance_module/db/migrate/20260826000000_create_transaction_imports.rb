class CreateTransactionImports < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_transaction_imports, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :financial_account, null: false, type: :uuid, foreign_key: true
      t.text :source_csv, null: false
      t.jsonb :column_mapping, null: false, default: {}
      t.jsonb :preview_rows, null: false, default: []
      t.integer :created_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.datetime :imported_at
      t.timestamps
    end
  end
end
