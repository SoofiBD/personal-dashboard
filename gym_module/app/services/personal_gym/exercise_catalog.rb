module PersonalGym
  class ExerciseCatalog
    CATALOG = [
      {name: "Barbell Bench Press", slug: "barbell-bench-press", category: :strength, logging_mode: :reps, muscle_group: "chest", equipment: "barbell", muscles: ["chest", "triceps", "front_delts"]},
      {name: "Incline Barbell Press", slug: "incline-barbell-press", category: :strength, logging_mode: :reps, muscle_group: "chest", equipment: "barbell", muscles: ["upper_chest", "front_delts"]},
      {name: "Dumbbell Bench Press", slug: "dumbbell-bench-press", category: :strength, logging_mode: :reps, muscle_group: "chest", equipment: "dumbbell", muscles: ["chest", "triceps"]},
      {name: "Push-up", slug: "push-up", category: :strength, logging_mode: :reps, muscle_group: "chest", equipment: "bodyweight", muscles: ["chest", "triceps"], bodyweight: true},
      {name: "Cable Fly", slug: "cable-fly", category: :strength, logging_mode: :reps, muscle_group: "chest", equipment: "cable", muscles: ["chest"]},
      {name: "Deadlift", slug: "deadlift", category: :strength, logging_mode: :reps, muscle_group: "back", equipment: "barbell", muscles: ["hamstrings", "glutes", "erectors", "lats"]},
      {name: "Barbell Row", slug: "barbell-row", category: :strength, logging_mode: :reps, muscle_group: "back", equipment: "barbell", muscles: ["lats", "rhomboids", "biceps"]},
      {name: "Pull-up", slug: "pull-up", category: :strength, logging_mode: :reps, muscle_group: "back", equipment: "bodyweight", muscles: ["lats", "biceps"], bodyweight: true},
      {name: "Lat Pulldown", slug: "lat-pulldown", category: :strength, logging_mode: :reps, muscle_group: "back", equipment: "cable", muscles: ["lats", "biceps"]},
      {name: "Seated Cable Row", slug: "seated-cable-row", category: :strength, logging_mode: :reps, muscle_group: "back", equipment: "cable", muscles: ["lats", "rhomboids"]},
      {name: "Overhead Press", slug: "overhead-press", category: :strength, logging_mode: :reps, muscle_group: "shoulders", equipment: "barbell", muscles: ["front_delts", "triceps"]},
      {name: "Lateral Raise", slug: "lateral-raise", category: :strength, logging_mode: :reps, muscle_group: "shoulders", equipment: "dumbbell", muscles: ["side_delts"]},
      {name: "Face Pull", slug: "face-pull", category: :strength, logging_mode: :reps, muscle_group: "shoulders", equipment: "cable", muscles: ["rear_delts", "rhomboids"]},
      {name: "Barbell Curl", slug: "barbell-curl", category: :strength, logging_mode: :reps, muscle_group: "arms", equipment: "barbell", muscles: ["biceps"]},
      {name: "Dumbbell Curl", slug: "dumbbell-curl", category: :strength, logging_mode: :reps, muscle_group: "arms", equipment: "dumbbell", muscles: ["biceps"], unilateral: true},
      {name: "Hammer Curl", slug: "hammer-curl", category: :strength, logging_mode: :reps, muscle_group: "arms", equipment: "dumbbell", muscles: ["biceps", "brachialis"], unilateral: true},
      {name: "Triceps Pushdown", slug: "triceps-pushdown", category: :strength, logging_mode: :reps, muscle_group: "arms", equipment: "cable", muscles: ["triceps"]},
      {name: "Skull Crusher", slug: "skull-crusher", category: :strength, logging_mode: :reps, muscle_group: "arms", equipment: "barbell", muscles: ["triceps"]},
      {name: "Back Squat", slug: "back-squat", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "barbell", muscles: ["quads", "glutes", "core"]},
      {name: "Front Squat", slug: "front-squat", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "barbell", muscles: ["quads", "core"]},
      {name: "Romanian Deadlift", slug: "romanian-deadlift", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "barbell", muscles: ["hamstrings", "glutes"]},
      {name: "Leg Press", slug: "leg-press", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "machine", muscles: ["quads", "glutes"]},
      {name: "Leg Extension", slug: "leg-extension", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "machine", muscles: ["quads"]},
      {name: "Leg Curl", slug: "leg-curl", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "machine", muscles: ["hamstrings"]},
      {name: "Walking Lunge", slug: "walking-lunge", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "dumbbell", muscles: ["quads", "glutes"], unilateral: true},
      {name: "Standing Calf Raise", slug: "standing-calf-raise", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "machine", muscles: ["calves"]},
      {name: "Hip Thrust", slug: "hip-thrust", category: :strength, logging_mode: :reps, muscle_group: "legs", equipment: "barbell", muscles: ["glutes", "hamstrings"]},
      {name: "Plank", slug: "plank", category: :timed, logging_mode: :time, muscle_group: "core", equipment: "bodyweight", muscles: ["core"], bodyweight: true},
      {name: "Hanging Leg Raise", slug: "hanging-leg-raise", category: :strength, logging_mode: :reps, muscle_group: "core", equipment: "bodyweight", muscles: ["core"], bodyweight: true},
      {name: "Cable Crunch", slug: "cable-crunch", category: :strength, logging_mode: :reps, muscle_group: "core", equipment: "cable", muscles: ["core"]},
      {name: "Russian Twist", slug: "russian-twist", category: :timed, logging_mode: :time, muscle_group: "core", equipment: "bodyweight", muscles: ["core"], bodyweight: true},
      {name: "Treadmill Run", slug: "treadmill-run", category: :cardio, logging_mode: :cardio, muscle_group: "cardio", equipment: "machine", muscles: []},
      {name: "Cycling", slug: "cycling", category: :cardio, logging_mode: :cardio, muscle_group: "cardio", equipment: "machine", muscles: []},
      {name: "Rowing Machine", slug: "rowing-machine", category: :cardio, logging_mode: :cardio, muscle_group: "cardio", equipment: "machine", muscles: []},
      {name: "Jump Rope", slug: "jump-rope", category: :cardio, logging_mode: :cardio, muscle_group: "cardio", equipment: "bodyweight", muscles: []}
    ].freeze

    def self.install!
      CATALOG.each do |attrs|
        PersonalGym::Exercise.find_or_create_by!(slug: attrs[:slug]) do |exercise|
          exercise.name = attrs[:name]
          exercise.category = attrs[:category]
          exercise.logging_mode = attrs[:logging_mode]
          exercise.muscle_group = attrs[:muscle_group]
          exercise.equipment = attrs[:equipment]
          exercise.muscles = attrs[:muscles]
          exercise.unilateral = attrs.fetch(:unilateral, false)
          exercise.bodyweight = attrs.fetch(:bodyweight, false)
        end
      end
      PersonalGym::Exercise.count
    end
  end
end
