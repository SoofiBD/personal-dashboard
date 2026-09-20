module PersonalGym
  class RoutineTemplates
    # slug -> plan satırı. Sadece ExerciseCatalog içindeki sluglar kullanılır.
    TEMPLATES = [
      {
        name: "Full Body 3 Gün",
        description: "Haftada 3 gün tüm vücut. Yeni başlayanlar için.",
        days: [
          {
            name: "Gün A",
            exercises: [
              {slug: "back-squat", sets: 3, reps: "5", weight: 60, policy: "linear"},
              {slug: "barbell-bench-press", sets: 3, reps: "5", weight: 40, policy: "linear"},
              {slug: "barbell-row", sets: 3, reps: "5", weight: 40, policy: "linear"},
              {slug: "plank", sets: 3, duration: 60, policy: "time"}
            ]
          },
          {
            name: "Gün B",
            exercises: [
              {slug: "deadlift", sets: 3, reps: "5", weight: 80, policy: "linear"},
              {slug: "overhead-press", sets: 3, reps: "5", weight: 30, policy: "linear"},
              {slug: "lat-pulldown", sets: 3, reps: "8-12", weight: 40, policy: "double"},
              {slug: "hanging-leg-raise", sets: 3, reps: "10", weight: 0, policy: "double"}
            ]
          },
          {
            name: "Gün C",
            exercises: [
              {slug: "front-squat", sets: 3, reps: "5", weight: 50, policy: "linear"},
              {slug: "incline-barbell-press", sets: 3, reps: "8", weight: 30, policy: "double"},
              {slug: "seated-cable-row", sets: 3, reps: "8-12", weight: 35, policy: "double"},
              {slug: "cable-crunch", sets: 3, reps: "12", weight: 20, policy: "double"}
            ]
          }
        ]
      },
      {
        name: "Upper / Lower 4 Gün",
        description: "Üst-alt ayrımı. Haftada 4 gün.",
        days: [
          {
            name: "Upper A",
            exercises: [
              {slug: "barbell-bench-press", sets: 4, reps: "5", weight: 40, policy: "linear"},
              {slug: "barbell-row", sets: 4, reps: "6", weight: 40, policy: "linear"},
              {slug: "overhead-press", sets: 3, reps: "8", weight: 25, policy: "double"},
              {slug: "barbell-curl", sets: 3, reps: "8-12", weight: 20, policy: "double"},
              {slug: "triceps-pushdown", sets: 3, reps: "8-12", weight: 20, policy: "double"}
            ]
          },
          {
            name: "Lower A",
            exercises: [
              {slug: "back-squat", sets: 4, reps: "5", weight: 60, policy: "linear"},
              {slug: "romanian-deadlift", sets: 3, reps: "8", weight: 60, policy: "double"},
              {slug: "leg-extension", sets: 3, reps: "10", weight: 30, policy: "double"},
              {slug: "standing-calf-raise", sets: 3, reps: "12", weight: 40, policy: "double"}
            ]
          },
          {
            name: "Upper B",
            exercises: [
              {slug: "overhead-press", sets: 4, reps: "5", weight: 30, policy: "linear"},
              {slug: "lat-pulldown", sets: 4, reps: "8", weight: 40, policy: "double"},
              {slug: "dumbbell-bench-press", sets: 3, reps: "8-12", weight: 16, policy: "double"},
              {slug: "hammer-curl", sets: 3, reps: "10", weight: 12, policy: "double"},
              {slug: "skull-crusher", sets: 3, reps: "10", weight: 20, policy: "double"}
            ]
          },
          {
            name: "Lower B",
            exercises: [
              {slug: "deadlift", sets: 3, reps: "5", weight: 80, policy: "linear"},
              {slug: "leg-press", sets: 3, reps: "10", weight: 100, policy: "double"},
              {slug: "leg-curl", sets: 3, reps: "10", weight: 30, policy: "double"},
              {slug: "hip-thrust", sets: 3, reps: "10", weight: 60, policy: "double"}
            ]
          }
        ]
      },
      {
        name: "5x5 Güç",
        description: "Klasik 5x5: A/B dönüşümlü, ağır bileşik hareketler.",
        days: [
          {
            name: "A Günü",
            exercises: [
              {slug: "back-squat", sets: 5, reps: "5", weight: 60, policy: "linear"},
              {slug: "barbell-bench-press", sets: 5, reps: "5", weight: 40, policy: "linear"},
              {slug: "barbell-row", sets: 5, reps: "5", weight: 40, policy: "linear"}
            ]
          },
          {
            name: "B Günü",
            exercises: [
              {slug: "back-squat", sets: 5, reps: "5", weight: 60, policy: "linear"},
              {slug: "overhead-press", sets: 5, reps: "5", weight: 30, policy: "linear"},
              {slug: "deadlift", sets: 1, reps: "5", weight: 80, policy: "linear"}
            ]
          }
        ]
      }
    ].freeze

    def self.install_for(user)
      ExerciseCatalog.install!
      created = 0
      TEMPLATES.each do |template|
        next if user.gym_routines.where(name: template[:name]).exists?

        routine = user.gym_routines.create!(name: template[:name], description: template[:description])
        template[:days].each_with_index do |day_attrs, day_index|
          day = routine.days.create!(name: day_attrs[:name], position: day_index + 1)
          day_attrs[:exercises].each_with_index do |plan, plan_index|
            exercise = PersonalGym::Exercise.find_by!(slug: plan[:slug])
            day.routine_exercises.create!(
              exercise: exercise,
              position: plan_index + 1,
              target_sets: plan[:sets],
              target_reps: plan[:reps],
              target_weight: plan[:weight],
              target_duration_seconds: plan[:duration],
              progression_policy: plan[:policy]
            )
          end
        end
        created += 1
      end
      created
    end
  end
end
