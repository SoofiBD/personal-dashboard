require "test_helper"

class PersonalFinance::PdfDocumentConversionJobTest < ActiveJob::TestCase
  setup do
    @conversion = PersonalFinance::DocumentConversion.create!(
      user: User.dashboard_owner, source_filename: "report.pdf", source_pdf_data: "%PDF-test", source_pdf_byte_size: 9
    )
    @conversion.processing!
  end

  test "stores the worker result and replaces old assets" do
    @conversion.assets.create!(filename: "old.png", content_type: "image/png", byte_size: 3, width: 100, height: 100, page_number: 1, data: "old")
    result = {
      markdown_content: "# Converted",
      processing_stats: {"page_count" => 2},
      assets: [{"filename" => "img_p2_1.png", "content_type" => "image/png", "data_base64" => Base64.strict_encode64("new"), "width" => 200, "height" => 120, "page" => 2}]
    }
    client = Class.new do
      attr_reader :arguments
      define_method(:initialize) { |conversion_result| @conversion_result = conversion_result }
      define_method(:convert) { |**arguments| @arguments = arguments; @conversion_result }
    end.new(result)

    PdfConversionClient.singleton_class.define_method(:new) { client }
    begin
      PersonalFinance::PdfDocumentConversionJob.perform_now(@conversion.id, "inline")
    ensure
      PdfConversionClient.singleton_class.remove_method(:new)
    end

    assert_predicate @conversion.reload, :completed?
    assert_equal "# Converted", @conversion.markdown_content
    assert_equal ["img_p2_1.png"], @conversion.assets.pluck(:filename)
    assert_equal "inline", client.arguments[:annotation_mode]
    assert_equal "%PDF-test", client.arguments[:pdf_data]
  end
end
