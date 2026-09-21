module PersonalGym
  class ExercisesController < ApplicationController
    before_action :set_exercise, only: %i[show]

    def index
      @exercises = Exercise.ordered
      @exercises = @exercises.search(params[:q]) if params[:q].present?
      @exercises = @exercises.where(muscle_group: params[:muscle]) if params[:muscle].present?
    end

    def show
      @history = current_user.gym_workouts.finished
        .joins(:sets)
        .where(gym_workout_sets: {exercise_id: @exercise.id})
        .recent_first.with_details.distinct.limit(10)
      @best_set = Gym::OneRm.best_set_of(
        WorkoutSet.joins(:workout)
          .where(gym_workouts: {user_id: current_user.id, status: "finished"}, exercise_id: @exercise.id)
      )
      @series = Gym::WorkoutQueries.e1rm_series(current_user, @exercise)
    end

    def new
      @exercise = Exercise.new(category: "strength", logging_mode: "reps")
    end

    def create
      @exercise = Exercise.new(exercise_params)
      @exercise.slug = unique_slug(@exercise.name)
      if @exercise.save
        redirect_to gym_exercises_path, notice: t("gym.exercise_saved", default: "Egzersiz eklendi.")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def seed
      count = PersonalGym::ExerciseCatalog.install!
      redirect_to gym_root_path, notice: t("gym.catalog_seeded", count: count, default: "#{count} egzersiz kataloğa eklendi.")
    end

    private

    def set_exercise
      @exercise = Exercise.find(params[:id])
    end

    def exercise_params
      params.require(:gym_exercise).permit(:name, :category, :logging_mode, :muscle_group, :equipment, :bodyweight, :unilateral)
    end

    def unique_slug(name)
      base = name.to_s.parameterize.presence || "egzersiz"
      slug = base
      counter = 2
      while Exercise.where("LOWER(slug) = ?", slug.downcase).exists?
        slug = "#{base}-#{counter}"
        counter += 1
      end
      slug
    end
  end
end
