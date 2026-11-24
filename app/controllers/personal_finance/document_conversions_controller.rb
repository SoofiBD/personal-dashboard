module PersonalFinance
  class DocumentConversionsController < ApplicationController
    skip_before_action :ensure_onboarding_completed

    def index
      @document_conversions = recent_conversions
      @document_conversion = owned(DocumentConversion).new
    end

    def create
      upload = params[:pdf_file]
      @document_conversion = owned(DocumentConversion).new(
        status: "processing",
        source_filename: File.basename(upload.try(:original_filename).to_s),
        custom_notes: document_conversion_params[:custom_notes],
        conversion_options: conversion_options
      )
      return render_invalid_upload("must be a PDF file") unless pdf_upload?(upload)

      @document_conversion.source_pdf.attach(upload)
      return render_invalid_upload unless @document_conversion.save

      PdfDocumentConversionJob.perform_later(@document_conversion.id, annotation_mode)
      audit_security_event("document_conversion_queued", conversion_id: @document_conversion.id, bytes: upload.size)
      redirect_to finance_document_conversion_path(@document_conversion), notice: "PDF dönüşümü sıraya alındı. Tamamlandığında çalışma alanı hazır olacak."
    end

    def show
      @document_conversion = owned(DocumentConversion).find(params[:id])
    end

    def source_pdf
      document_conversion = owned(DocumentConversion).find(params[:id])
      unless document_conversion.source_pdf_available?
        return redirect_to finance_document_conversion_path(document_conversion), alert: "Bu dönüşüm için kaynak PDF saklanmamış."
      end

      send_data document_conversion.source_pdf.download,
        filename: document_conversion.source_filename,
        type: "application/pdf",
        disposition: "inline"
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
      unless document_conversion.source_pdf_available?
        return redirect_to finance_document_conversion_path(document_conversion), alert: "Bu dönüşüm için kaynak PDF saklanmamış."
      end

      document_conversion.update!(status: "processing", conversion_options: conversion_options(saved_options: document_conversion.conversion_options))
      PdfDocumentConversionJob.perform_later(document_conversion.id, annotation_mode)
      audit_security_event("document_conversion_requeued", conversion_id: document_conversion.id)
      redirect_to finance_document_conversion_path(document_conversion), notice: "PDF güncel ayarlarla yeniden işlenmek üzere sıraya alındı."
    end

    def export_zip
      export(:zip, "application/zip")
    end

    def export_html
      export(:html, "text/html")
    end

    private

    def export(format, content_type)
      document_conversion = owned(DocumentConversion).completed.find(params[:id])
      body = PdfConversionClient.new.export(
        format,
        markdown_content: params[:markdown_content].presence || document_conversion.markdown_content,
        source_filename: document_conversion.source_filename,
        assets: document_conversion.assets
      )
      audit_security_event("document_conversion_#{format}_exported", conversion_id: document_conversion.id)
      send_data body, filename: "#{File.basename(document_conversion.source_filename, ".*")}.#{format}", type: content_type, disposition: "attachment"
    rescue PdfConversionClient::Error => e
      redirect_to finance_document_conversion_path(params[:id]), alert: e.message
    end

    def recent_conversions
      owned(DocumentConversion).order(created_at: :desc).limit(20)
    end

    def pdf_upload?(upload)
      return false unless upload.respond_to?(:read)

      magic = upload.read(5)
      upload.rewind
      magic == "%PDF-"
    end

    def render_invalid_upload(message = nil)
      @document_conversion.errors.add(:source_pdf, message) if message
      @document_conversions = recent_conversions
      render :index, status: :unprocessable_entity
    end

    def document_conversion_params
      params.fetch(:document_conversion, {}).permit(:custom_notes, :markdown_content)
    end

    # The form always posts every option (unchecked boxes send "0"); defaults
    # only fill keys a client leaves out.
    def conversion_options(saved_options: {})
      defaults = DocumentConversion::DEFAULT_OPTIONS.merge(saved_options.slice(*DocumentConversion::DEFAULT_OPTIONS.keys))
      submitted = params.fetch(:conversion_options, {}).permit(*defaults.keys).to_h
      defaults.to_h do |key, default|
        value = submitted.fetch(key, default)
        if key == "image_quality"
          [key, %w[balanced high maximum].include?(value) ? value : default]
        else
          [key, ActiveModel::Type::Boolean.new.cast(value)]
        end
      end
    end

    def annotation_mode
      DocumentConversion::ANNOTATION_MODES.include?(params[:annotation_mode]) ? params[:annotation_mode] : "both"
    end
  end
end
