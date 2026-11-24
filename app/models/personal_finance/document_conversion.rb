module PersonalFinance
  class DocumentConversion < ApplicationRecord
    self.table_name = "document_conversions"

    MAX_SOURCE_PDF_BYTES = 25.megabytes
    ANNOTATION_MODES = %w[both section inline].freeze
    # Per-conversion options sent to pdf_worker /convert (see pdf_worker/README.md).
    DEFAULT_OPTIONS = {
      "extract_images_enabled" => true, "image_quality" => "high",
      "strip_headers_footers" => true, "bind_captions_enabled" => true, "extract_annotations_enabled" => true,
      "include_yaml_frontmatter" => true, "fix_hyphenation_enabled" => true, "detect_tables" => true
    }.freeze

    belongs_to :user, class_name: "::User"
    has_one :invoice_parse, class_name: "PersonalFinance::InvoiceParse", foreign_key: :document_conversion_id, dependent: :destroy
    has_many :assets, class_name: "PersonalFinance::DocumentAsset", foreign_key: :document_conversion_id, dependent: :destroy
    has_one_attached :source_pdf

    enum :status, {pending: "pending", processing: "processing", completed: "completed", failed: "failed"}, validate: true

    validates :source_filename, presence: true, length: {maximum: 255}
    validates :custom_notes, length: {maximum: 10_000}, allow_blank: true
    validates :markdown_content, length: {maximum: 10_000_000}, allow_blank: true
    validate :source_pdf_size_is_allowed

    scope :older_than, ->(cutoff) { where("created_at < ?", cutoff) }

    def complete!(markdown_content:, processing_stats: {})
      update!(
        status: "completed",
        markdown_content: markdown_content,
        processing_stats: processing_stats,
        error_message: nil,
        completed_at: Time.current
      )
    end

    def fail!(message)
      update!(status: "failed", error_message: message.to_s.first(1_000), completed_at: Time.current)
    end

    def source_pdf_available?
      source_pdf.attached?
    end

    private

    def source_pdf_size_is_allowed
      return unless source_pdf.attached? && source_pdf.blob.byte_size > MAX_SOURCE_PDF_BYTES

      errors.add(:source_pdf, "must be 25 MB or smaller")
    end
  end
end
