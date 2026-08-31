class CreateDocumentAssets < ActiveRecord::Migration[7.2]
  def change
    create_table :document_assets, id: :uuid do |t|
      t.references :document_conversion, null: false, type: :uuid, foreign_key: true, index: {name: "index_document_assets_on_conversion_id"}
      t.string :filename, null: false, limit: 255
      t.string :content_type, null: false, limit: 100
      t.integer :byte_size, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.integer :page_number, null: false
      t.binary :data, null: false
      t.timestamps
    end

    add_index :document_assets, %i[document_conversion_id filename], unique: true
    add_check_constraint :document_assets, "byte_size > 0", name: "document_assets_byte_size_positive"
    add_check_constraint :document_assets, "width > 0 AND height > 0", name: "document_assets_dimensions_positive"
    add_check_constraint :document_assets, "page_number > 0", name: "document_assets_page_number_positive"
  end
end
