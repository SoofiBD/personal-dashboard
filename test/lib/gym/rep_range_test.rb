require "test_helper"

class GymRepRangeTest < ActiveSupport::TestCase
  test "normalizes a single repetition target" do
    assert_equal({min: 5, max: 5}, Gym::RepRange.normalize("5"))
  end

  test "normalizes a repetition range in either order" do
    assert_equal({min: 8, max: 12}, Gym::RepRange.normalize("8-12"))
    assert_equal({min: 8, max: 12}, Gym::RepRange.normalize("12-8"))
  end

  test "returns nil for an invalid target" do
    assert_nil Gym::RepRange.normalize("heavy")
    assert_nil Gym::RepRange.normalize(nil)
  end
end
