module PersonalFinance
  class InvoiceParser
    # Returns a hash with keys: :vendor, :invoice_date (Date), :amount (BigDecimal), :currency (String), :raw_json (Hash)
    # If parsing fails, returns nil.
    def self.parse(markdown_content)
      # TODO: Replace with AI/OCR later.
      # For now, return nil to indicate no parsing.
      nil
    end
  end
end
