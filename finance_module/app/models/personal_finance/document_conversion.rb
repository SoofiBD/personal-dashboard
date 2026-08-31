module PersonalFinance
  class DocumentConversion < ApplicationRecord
    self.table_name = "document_conversions"

    belongs_to :user, class_name: "::User"
    has_many :assets, class_name: "PersonalFinance::DocumentAsset", foreign_key: :document_conversion_id, dependent: :destroy

    enum :status, {pending: "pending", processing: "processing", completed: "completed", failed: "failed"}, validate: true

    validates :source_filename, presence: true, length: {maximum: 255}
    validates :source_pdf_byte_size, numericality: {greater_than: 0, less_than_or_equal_to: 25.megabytes}, allow_nil: true
    validates :custom_notes, length: {maximum: 10_000}, allow_blank: true
    validates :markdown_content, length: {maximum: 10_000_000}, allow_blank: true

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
      source_pdf_data.present? && source_pdf_byte_size.to_i.positive?
    end
  end
end
