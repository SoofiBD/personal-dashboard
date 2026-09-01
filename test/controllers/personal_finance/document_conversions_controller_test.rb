require "test_helper"

class PersonalFinance::DocumentConversionsControllerTest < PersonalFinance::IntegrationTest
  setup do
    @user = User.dashboard_owner
    @user.update!(onboarded_at: Time.current)
    @conversion = PersonalFinance::DocumentConversion.create!(user: @user, source_filename: "report.pdf")
    @conversion.source_pdf.attach(io: StringIO.new("%PDF-test"), filename: "report.pdf", content_type: "application/pdf")
    @conversion.complete!(markdown_content: "# Report")
  end

  test "shows the editable workspace for a completed conversion" do
    get finance_document_conversion_path(@conversion)

    assert_response :success
    assert_select "[data-document-workspace]"
    assert_select "textarea[data-markdown-editor]", text: "# Report"
    assert_select "[data-markdown-line-numbers]"
    assert_select "input[data-markdown-find]"
    assert_select "button[data-replace-all]", text: "Tümünü değiştir"
    assert_select "form[action='#{reprocess_finance_document_conversion_path(@conversion)}']"
    assert_select "form[action='#{export_html_finance_document_conversion_path(@conversion)}']"
    assert_select "a[href='#{source_pdf_finance_document_conversion_path(@conversion)}']", minimum: 2
    assert_select "object.document-source-viewer[type='application/pdf']"
    assert_select "#document-stats-title", text: "İşleme özeti"
    assert_select "[data-insert-image]", count: 0
  end

  test "serves the stored source PDF only to its owner" do
    get source_pdf_finance_document_conversion_path(@conversion)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal "%PDF-test", response.body
    assert_equal "inline", response.headers["Content-Disposition"].split(";").first
  end

  test "offers annotation output modes on the upload form" do
    get finance_document_conversions_path

    assert_response :success
    assert_select "input[name='annotation_mode'][value='both'][checked]"
    assert_select "input[name='annotation_mode'][value='section']"
    assert_select "input[name='annotation_mode'][value='inline']"
    assert_select "input[name='conversion_options[extract_images_enabled]'][value='1'][checked]"
    assert_select "select[name='conversion_options[min_image_dimension]']"
  end

  test "serves an image asset belonging to the current user" do
    asset = @conversion.assets.build(filename: "img_p1_1.png", content_type: "image/png", byte_size: 3, width: 100, height: 100, page_number: 1)
    asset.file.attach(io: StringIO.new("abc"), filename: asset.filename, content_type: asset.content_type)
    asset.save!

    get finance_document_conversion_asset_path(@conversion, asset)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "abc", response.body

    get finance_document_conversion_path(@conversion)
    assert_select "button[data-insert-image][data-image-filename='img_p1_1.png']", text: "Markdown’a ekle"
  end

  test "persists edited markdown for the current user" do
    patch finance_document_conversion_path(@conversion), params: {document_conversion: {markdown_content: "# Updated report"}}, as: :json

    assert_response :success
    assert_equal "# Updated report", @conversion.reload.markdown_content
  end

  test "destroys the conversion and its extracted assets" do
    asset = @conversion.assets.build(filename: "img_p1_1.png", content_type: "image/png", byte_size: 3, width: 100, height: 100, page_number: 1)
    asset.file.attach(io: StringIO.new("abc"), filename: asset.filename, content_type: asset.content_type)
    asset.save!

    assert_difference("PersonalFinance::DocumentConversion.count", -1) do
      assert_difference("PersonalFinance::DocumentAsset.count", -1) do
        delete finance_document_conversion_path(@conversion)
      end
    end

    assert_redirected_to finance_document_conversions_path
    follow_redirect!
    assert_select ".flash", text: /kaynak PDF ve çıkarılan görseller silindi/
  end

  test "queues reprocessing with the selected options" do
    old_asset = @conversion.assets.build(filename: "old.png", content_type: "image/png", byte_size: 3, width: 100, height: 100, page_number: 1)
    old_asset.file.attach(io: StringIO.new("old"), filename: old_asset.filename, content_type: old_asset.content_type)
    old_asset.save!
    assert_enqueued_with(job: PersonalFinance::PdfDocumentConversionJob, args: [@conversion.id, "inline"]) do
      post reprocess_finance_document_conversion_path(@conversion), params: {annotation_mode: "inline", conversion_options: {extract_images_enabled: "0", min_image_dimension: "200"}}
    end

    assert_redirected_to finance_document_conversion_path(@conversion)
    assert_predicate @conversion.reload, :processing?
    assert_equal false, @conversion.conversion_options["extract_images_enabled"]
    assert_equal 200, @conversion.conversion_options["min_image_dimension"]
  end

  test "shows an auto-refreshing processing state" do
    @conversion.processing!

    get finance_document_conversion_path(@conversion)

    assert_response :success
    assert_select "[data-document-conversion-processing]", text: /otomatik yenilenecek/
  end
end
