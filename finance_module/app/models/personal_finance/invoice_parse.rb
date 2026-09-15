module PersonalFinance
  class InvoiceParse < ApplicationRecord
    self.table_name = "invoice_parses"

    belongs_to :document_conversion, class_name: "::PersonalFinance::DocumentConversion", foreign_key: :document_conversion_id

    validates :document_conversion_id, uniqueness: true
  end
end
