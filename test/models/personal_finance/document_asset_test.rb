require "test_helper"

class PersonalFinance::DocumentAssetTest < ActiveSupport::TestCase
  setup do
    @conversion = PersonalFinance::DocumentConversion.create!(user: User.dashboard_owner, source_filename: "report.pdf")
  end

  test "requires binary data to match its declared byte size" do
    asset = @conversion.assets.build(
      filename: "img_p1_1.png", content_type: "image/png", byte_size: 2,
      width: 100, height: 100, page_number: 1, data: "abc"
    )

    assert_not_predicate asset, :valid?
    assert_includes asset.errors[:data], "must match byte_size"
  end

  test "accepts a safe image asset" do
    asset = @conversion.assets.build(
      filename: "img_p1_1.png", content_type: "image/png", byte_size: 3,
      width: 100, height: 100, page_number: 1, data: "abc"
    )

    assert_predicate asset, :valid?
  end
end
