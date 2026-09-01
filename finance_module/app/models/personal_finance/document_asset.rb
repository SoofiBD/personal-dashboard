module PersonalFinance
  class DocumentAsset < ApplicationRecord
    self.table_name = "document_assets"

    belongs_to :document_conversion, class_name: "PersonalFinance::DocumentConversion"
    has_one_attached :file

    validates :filename, presence: true, length: {maximum: 255}, format: {with: /\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/}
    validates :content_type, inclusion: {in: %w[image/png image/jpeg image/gif image/webp]}
    validates :byte_size, numericality: {greater_than: 0}
    validates :width, :height, :page_number, numericality: {only_integer: true, greater_than: 0}
    validate :file_is_attached
    validate :data_size_matches_byte_size

    def binary_data
      file.download
    end

    private

    def data_size_matches_byte_size
      return unless file.attached? && byte_size.present? && file.blob.byte_size != byte_size

      errors.add(:file, "must match byte_size")
    end

    def file_is_attached
      errors.add(:file, "must be attached") unless file.attached?
    end
  end
end
