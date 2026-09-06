require "test_helper"

class PersonalFinance::PurgeExpiredDocumentConversionsJobTest < ActiveJob::TestCase
  test "purges only conversions older than the configured retention period" do
    user = User.dashboard_owner
    old_conversion = PersonalFinance::DocumentConversion.create!(user: user, source_filename: "old.pdf")
    old_conversion.update_column(:created_at, 91.days.ago)
    current_conversion = PersonalFinance::DocumentConversion.create!(user: user, source_filename: "current.pdf")

    PersonalFinance::PurgeExpiredDocumentConversionsJob.perform_now

    assert_not PersonalFinance::DocumentConversion.exists?(old_conversion.id)
    assert PersonalFinance::DocumentConversion.exists?(current_conversion.id)
  end
end
