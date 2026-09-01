require "base64"
require "stringio"

module PersonalFinance
  class PdfDocumentConversionJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(document_conversion_id, annotation_mode)
      conversion = DocumentConversion.find(document_conversion_id)
      return unless conversion.processing?

      result = PdfConversionClient.new.convert(
        pdf_data: conversion.source_pdf_binary,
        filename: conversion.source_filename,
        custom_notes: conversion.custom_notes,
        annotation_mode: annotation_mode,
        conversion_options: conversion.conversion_options
      )

      ActiveRecord::Base.transaction do
        conversion.assets.destroy_all
        result.fetch(:assets).each do |asset|
          binary_data = Base64.strict_decode64(asset.fetch("data_base64"))
          document_asset = conversion.assets.build(
            filename: asset.fetch("filename"), content_type: asset.fetch("content_type"),
            byte_size: binary_data.bytesize,
            width: asset.fetch("width"), height: asset.fetch("height"), page_number: asset.fetch("page")
          )
          document_asset.file.attach(io: StringIO.new(binary_data), filename: document_asset.filename, content_type: document_asset.content_type)
          document_asset.save!
        end
        conversion.complete!(markdown_content: result.fetch(:markdown_content), processing_stats: result.fetch(:processing_stats))
      end
    rescue PdfConversionClient::Error => error
      conversion&.fail!(error.message) if conversion&.persisted?
      raise
    rescue KeyError, ArgumentError => error
      conversion&.fail!("PDF worker geçersiz görsel verisi döndürdü.") if conversion&.persisted?
      raise PdfConversionClient::Error, error.message
    end
  end
end
