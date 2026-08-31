require "test_helper"

class PersonalFinance::DocumentConversionTest < ActiveSupport::TestCase
  test "completing a conversion records its result and processing metadata" do
    conversion = PersonalFinance::DocumentConversion.create!(
      user: User.dashboard_owner,
      source_filename: "report.pdf"
    )

    conversion.complete!(markdown_content: "# Report", processing_stats: {"page_count" => 1})

    assert_predicate conversion, :completed?
    assert_equal "# Report", conversion.markdown_content
    assert_equal 1, conversion.processing_stats["page_count"]
    assert_not_nil conversion.completed_at
  end

  test "custom notes have a bounded length" do
    conversion = PersonalFinance::DocumentConversion.new(
      user: User.dashboard_owner,
      source_filename: "report.pdf",
      custom_notes: "x" * 10_001
    )

    assert_not_predicate conversion, :valid?
    assert conversion.errors.added?(:custom_notes, :too_long, count: 10_000)
  end

  test "reports whether the source PDF can be reprocessed" do
    conversion = PersonalFinance::DocumentConversion.new(user: User.dashboard_owner, source_filename: "report.pdf")

    assert_not_predicate conversion, :source_pdf_available?

    conversion.source_pdf_data = "%PDF-test"
    conversion.source_pdf_byte_size = conversion.source_pdf_data.bytesize
    assert_predicate conversion, :source_pdf_available?
  end

  test "selects conversions older than a cutoff for retention cleanup" do
    old = PersonalFinance::DocumentConversion.create!(user: User.dashboard_owner, source_filename: "old.pdf", created_at: 91.days.ago)
    recent = PersonalFinance::DocumentConversion.create!(user: User.dashboard_owner, source_filename: "recent.pdf", created_at: 2.days.ago)

    assert_includes PersonalFinance::DocumentConversion.older_than(90.days.ago), old
    assert_not_includes PersonalFinance::DocumentConversion.older_than(90.days.ago), recent
  end
end
