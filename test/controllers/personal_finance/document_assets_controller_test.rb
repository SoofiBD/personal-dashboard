require "test_helper"
require "minitest/mock"

class PersonalFinance::DocumentAssetsControllerTest < PersonalFinance::IntegrationTest
  setup do
    @user = User.dashboard_owner
    @user.update!(onboarded_at: Time.current)
    @conversion = PersonalFinance::DocumentConversion.create!(user: @user, source_filename: "report.pdf")
    @conversion.complete!(markdown_content: "![Figure](images/figure.png)")
    @asset = @conversion.assets.build(filename: "figure.png", content_type: "image/png", byte_size: 8, width: 200, height: 300, page_number: 1)
    @asset.file.attach(io: StringIO.new("original"), filename: @asset.filename, content_type: @asset.content_type)
    @asset.save!
    @path = finance_document_conversion_asset_path(@conversion, @asset)
  end

  test "saves crop for exports and previews while retaining the original and restoring it" do
    client = Minitest::Mock.new
    client.expect(:crop_image, "cropped") do |asset:, bounds:|
      asset.id == @asset.id && bounds == {"left" => 20, "top" => 30, "width" => 100, "height" => 150}
    end
    PdfConversionClient.stub(:new, client) do
      patch @path, params: {left: 20, top: 30, width: 100, height: 150}, as: :json
    end
    assert_response :success
    client.verify
    assert_equal "cropped", @asset.reload.binary_data
    assert_equal "original", @asset.file.download
    assert_equal "![Figure](images/figure.png)", @conversion.reload.markdown_content
    get @path
    assert_equal "cropped", response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    get @path, params: {original: "1"}
    assert_equal "original", response.body
    delete @path, as: :json
    assert_response :success
    assert_equal "original", @asset.reload.binary_data
    assert PersonalFinance::DocumentAsset.exists?(@asset.id)
  end

  test "rejects invalid coordinates without changing the file" do
    [{left: -1, top: 0, width: 10, height: 10}, {left: 190, top: 0, width: 20, height: 10}, {left: 0, top: 0, width: 0, height: 10}, {left: "1.5", top: 0, width: 10, height: 10}, {}].each do |bounds|
      patch @path, params: bounds, as: :json
      assert_response :unprocessable_entity
      assert_equal "original", @asset.reload.binary_data
    end
  end

  test "worker failure keeps the original available" do
    client = Object.new
    def client.crop_image(**)
      raise PdfConversionClient::Error, "Service unavailable"
    end
    PdfConversionClient.stub(:new, client) do
      patch @path, params: {left: 0, top: 0, width: 10, height: 10}, as: :json
    end
    assert_response :unprocessable_entity
    assert_equal "original", @asset.reload.binary_data
  end

  test "renders crop controls and filename based preview mapping" do
    get finance_document_conversion_path(@conversion)
    assert_response :success
    assert_select "button[data-crop-image][data-asset-url='#{@path}']"
    assert_select "dialog[data-image-crop-dialog]"
    assert_select "input[data-crop-field]", count: 4
    assert_select "[data-document-workspace]" do |elements|
      assert_equal @path, JSON.parse(elements.first["data-document-assets"])["figure.png"]
    end
  end

  test "cannot access assets through a different conversion" do
    other = PersonalFinance::DocumentConversion.create!(user: @user, source_filename: "other.pdf")
    path = finance_document_conversion_asset_path(other, @asset)
    get path
    assert_response :not_found
    patch path, params: {left: 0, top: 0, width: 10, height: 10}, as: :json
    assert_response :not_found
    delete path, as: :json
    assert_response :not_found
  end
end
