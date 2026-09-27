require "test_helper"

class PersonalGym::GymFlowTest < PersonalFinance::IntegrationTest
  setup do
    User.dashboard_owner.update!(onboarded_at: Time.current)
    PersonalGym::ExerciseCatalog.install!
  end

  test "viewer can browse gym but cannot create workouts or shared exercises" do
    viewer = User.create!(name: "Viewer", email: "gym-viewer@example.test", role: "viewer", currency: "TRY", time_zone: "Europe/Istanbul", password: TEST_PASSWORD, password_confirmation: TEST_PASSWORD, onboarded_at: Time.current)
    delete session_path
    post session_path, params: {identifier: viewer.email, password: TEST_PASSWORD}

    get gym_root_path
    assert_response :success
    assert_no_difference("PersonalGym::Exercise.count") do
      post gym_exercises_path, params: {gym_exercise: {name: "Unapproved", category: "strength", logging_mode: "reps"}}
    end
    assert_redirected_to gym_root_path
    assert_no_difference("PersonalGym::Workout.count") do
      post gym_workouts_path
    end
    assert_redirected_to gym_root_path
  end

  test "a routine can be started, logged, finished, and analyzed" do
    user = User.dashboard_owner
    exercise = PersonalGym::Exercise.find_by!(slug: "barbell-bench-press")
    routine = user.gym_routines.create!(name: "Push")
    day = routine.days.create!(name: "Day 1", position: 1)
    day.routine_exercises.create!(
      exercise: exercise,
      target_sets: 3,
      target_reps: "5",
      target_weight: 100,
      progression_policy: "linear",
      position: 1
    )

    post gym_workouts_path, params: {routine_day_id: day.id}
    assert_response :redirect
    workout = PersonalGym::Workout.last
    assert_equal 3, workout.sets.count
    follow_redirect!
    assert_response :success
    assert_select "[data-gym-timer]"

    workout.sets.each do |set|
      patch gym_workout_set_path(workout, set), params: {
        gym_workout_set: {weight: "100", reps: "5", done: "1"}
      }
      assert_response :redirect
    end

    patch finish_gym_workout_path(workout)
    assert_redirected_to gym_workout_path(workout)
    follow_redirect!
    assert_response :success
    assert_select "h1"

    get gym_stats_path
    assert_response :success
    assert_select "canvas#gym-volume-chart"
    assert_select "script[data-gym-volume-data]"

    get gym_exercise_path(exercise)
    assert_response :success
    assert_select "h1", exercise.name
  end
end
