class AddConversionOptionsToDocumentConversions < ActiveRecord::Migration[7.2]
  def change
    add_column :document_conversions, :conversion_options, :jsonb, null: false, default: {}
  end
end
