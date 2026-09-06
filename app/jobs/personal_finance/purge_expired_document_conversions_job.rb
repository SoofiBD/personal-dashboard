module PersonalFinance
  class PurgeExpiredDocumentConversionsJob < ApplicationJob
    queue_as :default

    def perform
      retention_days = Integer(ENV.fetch("DOCUMENT_RETENTION_DAYS", "90"))
      raise ArgumentError, "DOCUMENT_RETENTION_DAYS must be at least 1" if retention_days < 1

      DocumentConversion.older_than(retention_days.days.ago).find_each(&:destroy!)
    end
  end
end
