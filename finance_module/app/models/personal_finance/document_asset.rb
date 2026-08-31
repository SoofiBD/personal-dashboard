module PersonalFinance
  class DocumentAsset < ApplicationRecord
    self.table_name = "document_assets"

    belongs_to :document_conversion, class_name: "PersonalFinance::DocumentConversion"

    validates :filename, presence: true, length: {maximum: 255}, format: {with: /\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/}
    validates :content_type, inclusion: {in: %w[image/png image/jpeg image/gif image/webp]}
    validates :byte_size, numericality: {greater_than: 0}
    validates :width, :height, :page_number, numericality: {only_integer: true, greater_than: 0}
    validate :data_size_matches_byte_size

    private

    def data_size_matches_byte_size
      return if data.blank? || byte_size.blank? || data.bytesize == byte_size

      errors.add(:data, "must match byte_size")
    end
  end
end
