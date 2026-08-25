class AddMultiCurrencySupport < ActiveRecord::Migration[7.1]
  def change
    add_column :financial_accounts, :currency, :string, null: false, default: "TRY"
    add_index :financial_accounts, :currency

    create_table :finance_exchange_rates, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :base_currency, null: false, limit: 3
      t.string :quote_currency, null: false, limit: 3
      t.decimal :rate, null: false, precision: 18, scale: 6
      t.timestamps
    end
    add_index :finance_exchange_rates, %i[user_id base_currency quote_currency], unique: true, name: "index_exchange_rates_on_user_and_currencies"
  end
end
