class CreateInvoiceParses < ActiveRecord::Migration[7.2]
  def change
    create_table :invoice_parses, id: :uuid do |t|
      t.references :document_conversion, null: false, foreign_key: { to_table: :document_conversions }, type: :uuid
      t.string :vendor
      t.date :invoice_date
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, default: -> { 'TRY' }
      t.jsonb :raw_json, null: false, default: {}
      t.timestamps
    end

    add_index :invoice_parses, :document_conversion_id, unique: true
  end
end
