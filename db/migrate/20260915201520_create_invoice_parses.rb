class CreateInvoiceParses < ActiveRecord::Migration[7.2]
  def change
    create_table :invoice_parses, id: :uuid do |t|
      t.references :document_conversion,
        null: false,
        type: :uuid,
        foreign_key: {to_table: :document_conversions},
        index: {unique: true}
      t.string :vendor
      t.date :invoice_date
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, default: "TRY"
      t.jsonb :raw_json, null: false, default: {}
      t.timestamps
    end
  end
end
