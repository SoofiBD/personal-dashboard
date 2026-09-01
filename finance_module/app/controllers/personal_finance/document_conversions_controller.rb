require "stringio"

module PersonalFinance
  class DocumentConversionsController < ApplicationController
    def index
      @document_conversions = owned(DocumentConversion).order(created_at: :desc).limit(20)
      @document_conversion = owned(DocumentConversion).new
    end

    def create
      upload = params[:pdf_file]
      source_pdf_data = upload&.read
      @document_conversion = owned(DocumentConversion).new(
        source_filename: File.basename(upload&.original_filename.to_s),
        custom_notes: document_conversion_params[:custom_notes],
        conversion_options: conversion_options
      )
      @document_conversion.source_pdf.attach(io: StringIO.new(source_pdf_data), filename: @document_conversion.source_filename, content_type: "application/pdf") if source_pdf_data.present?

      begin
        @document_conversion.save!
        @document_conversion.processing!
        PdfDocumentConversionJob.perform_later(@document_conversion.id, annotation_mode)
        redirect_to finance_document_conversion_path(@document_conversion), notice: "PDF dönüşümü sıraya alındı. Tamamlandığında çalışma alanı hazır olacak."
      rescue ActiveRecord::RecordInvalid
        @document_conversions = owned(DocumentConversion).order(created_at: :desc).limit(20)
        render :index, status: :unprocessable_entity
      end
    end

    def show
      @document_conversion = owned(DocumentConversion).find(params[:id])
    end

    def source_pdf
      document_conversion = owned(DocumentConversion).find(params[:id])
      raise PdfConversionClient::Error, "Bu dönüşüm için kaynak PDF saklanmamış." unless document_conversion.source_pdf_available?

      send_data document_conversion.source_pdf_binary,
        filename: document_conversion.source_filename,
        type: "application/pdf",
        disposition: "inline"
    rescue PdfConversionClient::Error => e
      redirect_to finance_document_conversion_path(params[:id]), alert: e.message
    end

    def update
      document_conversion = owned(DocumentConversion).completed.find(params[:id])
      document_conversion.update!(document_conversion_params)
      render json: {updated_at: document_conversion.updated_at.iso8601}
    rescue ActiveRecord::RecordInvalid => e
      render json: {error: e.record.errors.full_messages.to_sentence}, status: :unprocessable_entity
    end

    def destroy
      document_conversion = owned(DocumentConversion).find(params[:id])
      document_conversion.destroy!
      redirect_to finance_document_conversions_path, notice: "Dönüşüm, kaynak PDF ve çıkarılan görseller silindi."
    end

    def reprocess
      document_conversion = owned(DocumentConversion).find(params[:id])
      raise PdfConversionClient::Error, "Bu dönüşüm için kaynak PDF saklanmamış." unless document_conversion.source_pdf_available?

      options = conversion_options(saved_options: document_conversion.conversion_options)
      document_conversion.update!(conversion_options: options)
      document_conversion.processing!
      PdfDocumentConversionJob.perform_later(document_conversion.id, annotation_mode)
      redirect_to finance_document_conversion_path(document_conversion), notice: "PDF güncel ayarlarla yeniden işlenmek üzere sıraya alındı."
    rescue PdfConversionClient::Error => e
      redirect_to finance_document_conversion_path(params[:id]), alert: e.message
    end

    def export_zip
      document_conversion = owned(DocumentConversion).completed.find(params[:id])
      markdown_content = params[:markdown_content].presence || document_conversion.markdown_content
      zip = PdfConversionClient.new.export_zip(markdown_content: markdown_content, source_filename: document_conversion.source_filename, assets: document_conversion.assets)
      send_data zip, filename: "#{File.basename(document_conversion.source_filename, ".pdf")}.zip", type: "application/zip", disposition: "attachment"
    rescue PdfConversionClient::Error => e
      redirect_to finance_document_conversion_path(params[:id]), alert: e.message
    end

    def export_html
      document_conversion = owned(DocumentConversion).completed.find(params[:id])
      markdown_content = params[:markdown_content].presence || document_conversion.markdown_content
      html = PdfConversionClient.new.export_html(markdown_content: markdown_content, source_filename: document_conversion.source_filename, assets: document_conversion.assets)
      send_data html, filename: "#{File.basename(document_conversion.source_filename, ".pdf")}.html", type: "text/html", disposition: "attachment"
    rescue PdfConversionClient::Error => e
      redirect_to finance_document_conversion_path(params[:id]), alert: e.message
    end

    private

    def document_conversion_params
      params.fetch(:document_conversion, {}).permit(:custom_notes, :markdown_content)
    end

    def conversion_options(saved_options: {})
      defaults = {
        "extract_images_enabled" => true, "min_image_dimension" => 100, "strip_headers_footers" => true,
        "bind_captions_enabled" => true, "extract_annotations_enabled" => true,
        "include_yaml_frontmatter" => true, "fix_hyphenation_enabled" => true, "detect_tables" => true
      }
      submitted = params.fetch(:conversion_options, {}).permit(*defaults.keys).to_h
      defaults.merge!(saved_options.slice(*defaults.keys)) if saved_options.present?
      boolean_options = defaults.except("min_image_dimension").each_with_object({}) do |(key, default), options|
        options[key] = submitted.key?(key) ? ActiveModel::Type::Boolean.new.cast(submitted[key]) : default
      end
      boolean_options.merge("min_image_dimension" => submitted.fetch("min_image_dimension", defaults["min_image_dimension"]).to_i.clamp(50, 500))
    end

    def annotation_mode
      mode = params[:annotation_mode].to_s
      %w[section inline both].include?(mode) ? mode : "both"
    end
  end
end
