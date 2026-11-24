class RemoveLegacyDocumentBinaryColumns < ActiveRecord::Migration[7.2]
  def change
    remove_check_constraint :document_conversions, name: "document_conversions_source_pdf_byte_size_positive"
    remove_column :document_conversions, :source_pdf_data, :binary
    remove_column :document_conversions, :source_pdf_byte_size, :integer
    remove_column :document_assets, :data, :binary
  end
end
