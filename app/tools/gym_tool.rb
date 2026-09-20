# frozen_string_literal: true

class GymTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :list_routines, description: 'All routines with exercises' do
  end

  define_function :get_active_workout, description: 'Current workout + sets' do
  end

  define_function :get_recent_workouts, description: 'Last N workouts (default 5)' do
    property :limit, type: 'integer', description: 'Max results', required: false
  end

  define_function :list_exercises, description: 'Exercise catalog by muscle_group' do
    property :muscle_group, type: 'string', description: 'Muscle group filter', required: false
  end

  def list_routines
    routines = user.gym_routines.includes(days: { routine_exercises: :exercise }).map do |r|
      {
        id: r.id,
        name: r.name,
        description: r.description,
        days: r.days.order(:position).map do |d|
          { name: d.name, exercises: d.routine_exercises.order(:position).map do |re|
            { exercise: re.exercise.name, target_sets: re.target_sets, target_reps: re.target_reps, target_duration_seconds: re.target_duration_seconds }
          end }
        end
      }
    end
    tool_response(content: routines)
  end

  def get_active_workout
    workout = user.gym_workouts.active.first
    return tool_response(content: { error: 'No active workout' }) unless workout

    sets = workout.sets.includes(:exercise).order(:position).map do |s|
      { exercise: s.exercise.name, kind: s.kind, weight: s.weight&.to_f, reps: s.reps,
        duration_seconds: s.duration_seconds, done: s.done }
    end

    tool_response(content: { id: workout.id, started_at: workout.started_at, routine: workout.routine&.name,
                             sets: sets })
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
      { name: e.name, slug: e.slug, category: e.category, logging_mode: e.logging_mode, muscle_group: e.muscle_group,
        equipment: e.equipment }
    end
    tool_response(content: result)
  end

  private

  attr_reader :user

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
