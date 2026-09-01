require "test_helper"

class PersonalFinance::DocumentAssetTest < ActiveSupport::TestCase
  setup do
    @conversion = PersonalFinance::DocumentConversion.create!(user: User.dashboard_owner, source_filename: "report.pdf")
  end

  test "requires an attachment to match its declared byte size" do
    asset = @conversion.assets.build(
      filename: "img_p1_1.png", content_type: "image/png", byte_size: 2,
      width: 100, height: 100, page_number: 1
    )
    asset.file.attach(io: StringIO.new("abc"), filename: asset.filename, content_type: asset.content_type)

    assert_not_predicate asset, :valid?
    assert_includes asset.errors[:file], "must match byte_size"
  end

  test "accepts a safe image asset" do
    asset = @conversion.assets.build(
      filename: "img_p1_1.png", content_type: "image/png", byte_size: 3,
      width: 100, height: 100, page_number: 1
    )
    asset.file.attach(io: StringIO.new("abc"), filename: asset.filename, content_type: asset.content_type)

    assert_predicate asset, :valid?
  end
end
