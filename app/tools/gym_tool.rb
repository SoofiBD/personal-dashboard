# frozen_string_literal: true

class GymTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :list_routines, description: "All routines with exercises"

  define_function :get_active_workout, description: "Current workout + sets"

  define_function :get_recent_workouts, description: "Last N workouts (default 5)" do
    property :limit, type: "integer", description: "Max results", required: false
  end

  define_function :list_exercises, description: "Exercise catalog by muscle_group" do
    property :muscle_group, type: "string", description: "Muscle group filter", required: false
  end

  define_function :get_exercise, description: "Exercise details, including safe execution cues when available" do
    property :slug, type: "string", description: "Catalog exercise slug", required: true
  end

  define_function :create_program, description: "Propose a complete gym routine from a user-supplied plan. Never invent exercise slugs: call list_exercises first when unsure. plan_json must be valid JSON: {\"name\":\"...\",\"description\":\"...\",\"days\":[{\"name\":\"Day 1\",\"exercises\":[{\"exercise_slug\":\"barbell-bench-press\",\"sets\":3,\"reps\":\"8-10\",\"weight\":null,\"progression_policy\":\"linear\",\"warmup\":\"\"}]}]}. For time exercises use duration_seconds; for cardio use duration_seconds and progression_policy off. This only creates a confirmation proposal." do
    property :plan_json, type: "string", description: "Complete routine as valid JSON, using catalog exercise_slug values", required: true
  end

  define_function :record_body_weight, description: "Propose logging one body-weight measurement. This never writes directly." do
    property :weight_kg, type: "number", description: "Weight in kilograms, between 20 and 500", required: true
    property :recorded_on, type: "string", description: "ISO date YYYY-MM-DD; default today", required: false
    property :note, type: "string", description: "Optional short measurement note", required: false
  end

  define_function :schedule_workout, description: "Propose adding an existing routine day to the user's weekly schedule. This never writes directly." do
    property :routine_day_id, type: "string", description: "Routine day UUID from list_routines", required: true
    property :scheduled_on, type: "string", description: "ISO date YYYY-MM-DD", required: true
  end

  def list_routines
    routines = user.gym_routines.includes(days: {routine_exercises: :exercise}).map do |r|
      {
        id: r.id,
        name: r.name,
        description: r.description,
        days: r.days.order(:position).map do |d|
          {name: d.name, exercises: d.routine_exercises.order(:position).map do |re|
            {exercise: re.exercise.name, target_sets: re.target_sets, target_reps: re.target_reps, target_duration_seconds: re.target_duration_seconds}
          end}
        end
      }
    end
    tool_response(content: routines)
  end

  def get_active_workout
    workout = user.gym_workouts.active.first
    return tool_response(content: {error: "No active workout"}) unless workout

    sets = workout.sets.includes(:exercise).order(:position).map do |s|
      {exercise: s.exercise.name, kind: s.kind, weight: s.weight&.to_f, reps: s.reps,
       duration_seconds: s.duration_seconds, done: s.done}
    end

    tool_response(content: {id: workout.id, started_at: workout.started_at, routine: workout.routine&.name,
                            sets: sets})
  end

  def get_recent_workouts(limit: 5)
    workouts = user.gym_workouts.recent_first.with_details.limit(limit).map do |w|
      {
        id: w.id,
        status: w.status,
        started_at: w.started_at,
        finished_at: w.finished_at,
        routine: w.routine&.name,
        exercises: w.sets.includes(:exercise).map { |s| s.exercise.name }.uniq,
        total_sets: w.sets.count,
        duration: w.finished_at ? ((w.finished_at - w.started_at).to_i / 60) : nil
      }
    end
    tool_response(content: workouts)
  end

  def list_exercises(muscle_group: nil)
    exercises = PersonalGym::Exercise.all
    exercises = exercises.where(muscle_group: muscle_group) if muscle_group.present?

    result = exercises.order(:name).limit(50).map do |e|
      {name: e.name, slug: e.slug, category: e.category, logging_mode: e.logging_mode, muscle_group: e.muscle_group,
       equipment: e.equipment}
    end
    tool_response(content: result)
  end

  def get_exercise(slug:)
    exercise = PersonalGym::Exercise.find_by(slug: slug)
    return tool_response(content: {error: "Exercise not found"}) unless exercise

    tool_response(content: {
      id: exercise.id, name: exercise.name, slug: exercise.slug, category: exercise.category,
      logging_mode: exercise.logging_mode, muscle_group: exercise.muscle_group, muscles: exercise.muscles,
      equipment: exercise.equipment, instructions: exercise.instructions, safety_notes: exercise.safety_notes,
      demo_url: exercise.demo_url
    })
  end

  def create_program(plan_json:)
    plan = JSON.parse(plan_json)
    validated = validate_program!(plan)
    action = AiAction.propose!(
      user: user,
      action_type: "gym.create_program",
      payload: validated,
      summary: "Spor programı oluştur: #{validated.fetch("name")} (#{validated.fetch("days").size} gün)"
    )
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  rescue JSON::ParserError
    tool_response(content: {error: "Program planı geçerli JSON olmalıdır."})
  rescue ArgumentError => e
    tool_response(content: {error: e.message})
  end

  def record_body_weight(weight_kg:, recorded_on: nil, note: nil)
    weight = BigDecimal(weight_kg.to_s)
    raise ArgumentError, "Ağırlık 20 ile 500 kg arasında olmalıdır." unless weight.between?(20, 500)
    date = recorded_on.present? ? Date.iso8601(recorded_on) : Date.current
    action = AiAction.propose!(user: user, action_type: "gym.record_body_metric", payload: {"weight_kg" => weight.to_s("F"), "recorded_on" => date.iso8601, "note" => note.to_s.first(1_000)}, summary: "Vücut ağırlığı kaydet: #{weight.to_s("F")} kg (#{date})")
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  rescue ArgumentError => e
    tool_response(content: {error: e.message})
  end

  def schedule_workout(routine_day_id:, scheduled_on:)
    day = PersonalGym::RoutineDay.joins(:routine).find_by(id: routine_day_id, gym_routines: {user_id: user.id})
    return tool_response(content: {error: "Antrenman günü bulunamadı."}) unless day
    date = Date.iso8601(scheduled_on)
    action = AiAction.propose!(user: user, action_type: "gym.schedule_workout", payload: {"routine_day_id" => day.id, "scheduled_on" => date.iso8601}, summary: "Antrenmanı planla: #{day.routine.name} · #{day.name} (#{date})")
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  rescue Date::Error
    tool_response(content: {error: "Tarih YYYY-MM-DD biçiminde olmalıdır."})
  end

  private

  attr_reader :user

  def validate_program!(plan)
    raise ArgumentError, "Program bir JSON nesnesi olmalıdır." unless plan.is_a?(Hash)
    name = plan["name"].to_s.strip
    days = plan["days"]
    raise ArgumentError, "Program adı 1-120 karakter olmalıdır." unless name.length.between?(1, 120)
    raise ArgumentError, "Program 1-7 gün içermelidir." unless days.is_a?(Array) && days.size.between?(1, 7)

    exercise_count = 0
    normalized_days = days.map do |day|
      day_name = day.fetch("name", "").to_s.strip
      exercises = day["exercises"]
      raise ArgumentError, "Her günün adı ve en az bir hareketi olmalıdır." if day_name.blank? || !exercises.is_a?(Array) || exercises.empty?
      raise ArgumentError, "Bir günde en fazla 12 hareket olabilir." if exercises.size > 12

      normalized_exercises = exercises.map do |item|
        exercise = PersonalGym::Exercise.find_by(slug: item["exercise_slug"].to_s)
        raise ArgumentError, "Katalogda olmayan hareket: #{item["exercise_slug"]}" unless exercise
        exercise_count += 1
        normalize_exercise(item, exercise)
      end
      {"name" => day_name.first(80), "exercises" => normalized_exercises}
    end
    raise ArgumentError, "Programda en fazla 50 hareket olabilir." if exercise_count > 50

    {"name" => name, "description" => plan["description"].to_s.strip.first(500), "days" => normalized_days}
  end

  def normalize_exercise(item, exercise)
    sets = Integer(item.fetch("sets", 3))
    raise ArgumentError, "Set sayısı 1-20 arasında olmalıdır." unless sets.between?(1, 20)
    policy = item.fetch("progression_policy", exercise.mode_reps? ? "linear" : "off").to_s
    allowed = if exercise.mode_cardio?
      %w[off]
    else
      (exercise.mode_time? ? %w[off time] : Gym::Progression::POLICIES)
    end
    raise ArgumentError, "#{exercise.name} için ilerleme yöntemi geçersiz." unless allowed.include?(policy)

    result = {"exercise_id" => exercise.id, "sets" => sets, "progression_policy" => policy, "warmup" => item["warmup"].to_s.first(40)}
    if exercise.mode_reps?
      reps = item["reps"].to_s.strip
      raise ArgumentError, "#{exercise.name} için tekrar aralığı gerekli." if reps.blank? || reps.length > 20 || !Gym::RepRange.normalize(reps)
      result["reps"] = reps
      result["weight"] = BigDecimal(item["weight"].to_s) if item["weight"].present?
    else
      duration = Integer(item.fetch("duration_seconds"))
      raise ArgumentError, "#{exercise.name} için süre gerekli." unless duration.positive? && duration <= 14_400
      result["duration_seconds"] = duration
    end
    result
  rescue KeyError, ArgumentError => e
    raise ArgumentError, e.message
  end

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
