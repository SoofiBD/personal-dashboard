class AddSourcePdfToDocumentConversions < ActiveRecord::Migration[7.2]
  def change
    add_column :document_conversions, :source_pdf_data, :binary
    add_column :document_conversions, :source_pdf_byte_size, :integer
    add_check_constraint :document_conversions,
      "source_pdf_byte_size IS NULL OR source_pdf_byte_size > 0",
      name: "document_conversions_source_pdf_byte_size_positive"
  end
end
