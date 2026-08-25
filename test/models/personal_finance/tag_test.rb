require "test_helper"

class PersonalFinance::TagTest < ActiveSupport::TestCase
  test "normalizes whitespace and rejects case-insensitive duplicates for a user" do
    user = User.dashboard_owner
    tag = PersonalFinance::Tag.create!(user: user, name: "  Summer   Trip ")
    duplicate = PersonalFinance::Tag.new(user: user, name: "summer trip")

    assert_equal "Summer Trip", tag.name
    assert_not duplicate.valid?
  end
end
