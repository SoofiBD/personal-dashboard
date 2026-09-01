require "stringio"

class CopyDocumentBinariesToActiveStorage < ActiveRecord::Migration[7.2]
  class LegacyDocumentConversion < ActiveRecord::Base
    self.table_name = "document_conversions"
  end

  class LegacyDocumentAsset < ActiveRecord::Base
    self.table_name = "document_assets"
  end

  def up
    LegacyDocumentConversion.where.not(source_pdf_data: nil).find_each do |conversion|
      attach_unless_present(
        record_type: "PersonalFinance::DocumentConversion",
        record_id: conversion.id,
        name: "source_pdf",
        data: conversion.source_pdf_data,
        filename: conversion.source_filename,
        content_type: "application/pdf"
      )
    end

    LegacyDocumentAsset.where.not(data: nil).find_each do |asset|
      attach_unless_present(
        record_type: "PersonalFinance::DocumentAsset",
        record_id: asset.id,
        name: "file",
        data: asset.data,
        filename: asset.filename,
        content_type: asset.content_type
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Active Storage files are retained to protect uploaded documents."
  end

  private

  def attach_unless_present(record_type:, record_id:, name:, data:, filename:, content_type:)
    return if ActiveStorage::Attachment.exists?(record_type: record_type, record_id: record_id, name: name)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(data), filename: filename, content_type: content_type, service_name: "local"
    )
    ActiveStorage::Attachment.create!(name: name, record_type: record_type, record_id: record_id, blob: blob)
  end
end
