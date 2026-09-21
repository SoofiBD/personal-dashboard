require "test_helper"

class GymOneRmTest < ActiveSupport::TestCase
  HistorySet = Struct.new(:done, :kind, :weight, :reps) do
    def done?
      self[:done]
    end
  end

  test "estimates a one-rep max with the default Epley formula" do
    assert_in_delta 116.7, Gym::OneRm.estimate(100, 5), 0.1
  end

  test "returns the measured weight for a true single" do
    assert_equal 100.0, Gym::OneRm.estimate(100, 1)
  end

  test "refuses estimates outside honest input bounds" do
    assert_nil Gym::OneRm.estimate(100, 13)
    assert_nil Gym::OneRm.estimate(0, 5)
    assert_nil Gym::OneRm.estimate(100, 0)
  end

  test "selects the best completed working set" do
    sets = [
      HistorySet.new(true, "warmup", 135, 5),
      HistorySet.new(true, "working", 100, 5),
      HistorySet.new(true, "working", 100, 8),
      HistorySet.new(false, "working", 120, 5)
    ]

    best = Gym::OneRm.best_set_of(sets)

    assert_equal 8, best[:reps]
    assert_in_delta 126.7, best[:estimate], 0.1
  end
end
