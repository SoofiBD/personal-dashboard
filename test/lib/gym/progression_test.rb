require "test_helper"

class GymProgressionTest < ActiveSupport::TestCase
  HistorySet = Struct.new(:weight, :reps, :duration_seconds, :done) do
    def done?
      self[:done]
    end
  end

  test "linear progression advances after a complete session" do
    history = [
      HistorySet.new(100, 5, nil, true),
      HistorySet.new(100, 5, nil, true),
      HistorySet.new(100, 5, nil, true)
    ]
    progression = Gym::Progression.new(history_sets: history, target_sets: 3, target_reps: "5")

    target = progression.next_target("linear")

    assert_equal 102.5, target[:weight]
    assert_equal 5, target[:reps]
    assert_not_nil progression.reason
  end

  test "linear progression deloads after repeated misses" do
    history = [
      HistorySet.new(100, 5, nil, true),
      HistorySet.new(100, 3, nil, true),
      HistorySet.new(100, 3, nil, true)
    ]
    progression = Gym::Progression.new(history_sets: history, target_sets: 3, target_reps: "5")

    target = progression.next_target("linear")

    assert_equal 90.0, target[:weight]
  end

  test "greyskull progression doubles the jump on a dominant final set" do
    history = [
      HistorySet.new(100, 5, nil, true),
      HistorySet.new(100, 5, nil, true),
      HistorySet.new(100, 10, nil, true)
    ]
    progression = Gym::Progression.new(history_sets: history, target_sets: 3, target_reps: "5")

    target = progression.next_target("greyskull")

    assert_equal 105.0, target[:weight]
  end

  test "greyskull progression deloads after a failed session" do
    history = [
      HistorySet.new(100, 5, nil, true),
      HistorySet.new(100, 5, nil, true),
      HistorySet.new(100, 3, nil, true)
    ]
    progression = Gym::Progression.new(history_sets: history, target_sets: 3, target_reps: "5")

    target = progression.next_target("greyskull")

    assert_equal 90.0, target[:weight]
  end

  test "double progression resets repetitions after reaching the top" do
    history = [
      HistorySet.new(40, 12, nil, true),
      HistorySet.new(40, 12, nil, true)
    ]
    progression = Gym::Progression.new(history_sets: history, target_sets: 2, target_reps: "8-12")

    target = progression.next_target("double")

    assert_equal 42.5, target[:weight]
    assert_equal 8, target[:reps]
  end

  test "timed progression extends the hold after complete sets" do
    history = [
      HistorySet.new(nil, nil, 60, true),
      HistorySet.new(nil, nil, 60, true)
    ]
    progression = Gym::Progression.new(history_sets: history, target_sets: 2, target_duration_seconds: 60)

    target = progression.next_target("time")

    assert_equal 75, target[:duration_seconds]
  end
end
