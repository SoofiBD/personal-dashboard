module PersonalGym
  class ExerciseCatalog
    GUIDANCE = {
      "barbell-bench-press" => {instructions: "1. Gözlerin barın altında, ayakların yere sağlam basacak şekilde uzan.\n2. Kürek kemiklerini geriye-aşağı al; beli doğal kavisinde tut.\n3. Barı kontrollü biçimde alt göğse indir, dirsekleri gövdeden yaklaşık 45–75° açıda tut.\n4. Ayaklardan güç alıp barı başlangıç noktasına bastır; bilekleri barın altında hizalı tut.", safety_notes: "Omuzda keskin ağrı olursa dur. Ağır setlerde emniyet kolları veya spotter kullan."},
      "back-squat" => {instructions: "1. Barı üst sırtına yerleştir, karnını sıkıp kaburgaları kontrol et.\n2. Kalça ve dizleri birlikte kırarak dengeli biçimde çömel.\n3. Dizleri ayak parmaklarının yönünde takip ettir, topukları yerden kaldırma.\n4. Alt pozisyondan tüm ayağınla zemini iterek kalk.", safety_notes: "Belini nötr tut; ağrı veya denge kaybında seti sonlandır. Ağır setlerde rack güvenliklerini ayarla."},
      "deadlift" => {instructions: "1. Barı ayağın orta hizasına koy, kalçayı geriye gönderip bara yaklaş.\n2. Karnını sık, sırtını uzun ve nötr tut, koltuk altlarını gövdeye kilitle.\n3. Zemini iterek barı bacaklarına yakın kaldır.\n4. Kalçayı geriye göndererek barı aynı kontrollü hat üzerinden indir.", safety_notes: "Sırtı yuvarlayarak yerden koparma. Keskin bel ağrısında dur ve form/yük için uzman desteği al."},
      "overhead-press" => {instructions: "1. Barı omuz önünde, bilekler barın altında tut.\n2. Kalçayı sıkıp karnı brace et; belden geriye aşırı yatma.\n3. Barı yüze yakın dik hatta yukarı bastır.\n4. Başını barın altına getirip üstte kontrollü kilitle.", safety_notes: "Bel veya omuz ağrısında yükü azalt ya da dur. Dar alanlarda bar yolunu çevreden uzak tut."},
      "barbell-row" => {instructions: "1. Kalçadan menteşe yap, gövdeyi sabit ve sırtı nötr tut.\n2. Barı alt kaburgalara doğru çek; dirsekleri geriye sür.\n3. Kürek kemiklerini kontrollü sık.\n4. Barı sallanmadan başlangıca indir.", safety_notes: "Ağırlığı ivmeyle çekme. Bel pozisyonunu koruyamıyorsan yükü azalt."},
      "pull-up" => {instructions: "1. Barı kavra, omuzları kulaklardan uzaklaştır.\n2. Göğsünü bara yönlendirirken dirsekleri aşağı-arkaya çek.\n3. Üstte kontrol et, sonra omuzları kontrolü kaybetmeden tam açılmaya dön.\n4. Gerekirse lastik veya asist makinesiyle hareket aralığını koru.", safety_notes: "Omuzda sıkışma ya da ağrı hissedersen hareketi bırak."},
      "romanian-deadlift" => {instructions: "1. Dizleri hafif kır, barı bacaklara yakın tut.\n2. Kalçayı geriye gönderirken hamstringlerde gerilimi hisset.\n3. Sırtı nötr tutarak sadece kontrol edebildiğin derinliğe in.\n4. Kalçayı sıkarak ayağa kalk.", safety_notes: "Belden eğilme veya barı vücuttan uzaklaştırma. Hamstring ağrısında dur."},
      "plank" => {instructions: "1. Dirsekleri omuz altında, vücudu baştan topuğa düz çizgide kur.\n2. Karnı ve kalçayı sık, yere bakarak boynu uzun tut.\n3. Belin çökmesine veya kalçanın yükselmesine izin verme.\n4. Form bozulmadan süreyi tamamla.", safety_notes: "Bel ağrısı oluşursa seti bitir; daha kısa sürelerle ilerle."}
    }.freeze

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
        exercise = PersonalGym::Exercise.find_or_initialize_by(slug: attrs[:slug])
        exercise.assign_attributes(attrs.except(:slug)) if exercise.new_record?
        guide = GUIDANCE[attrs[:slug]]
        exercise.instructions = guide[:instructions] if guide && exercise.instructions.blank?
        exercise.safety_notes = guide[:safety_notes] if guide && exercise.safety_notes.blank?
        exercise.save!
      end
      PersonalGym::Exercise.count
    end
  end
end
