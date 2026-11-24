class CreatePersonalGymCore < ActiveRecord::Migration[7.2]
  def change
    create_table :gym_exercises, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category, null: false, default: "strength"
      t.string :logging_mode, null: false, default: "reps"
      t.string :muscle_group
      t.string :equipment
      t.jsonb :muscles, null: false, default: []
      t.boolean :unilateral, null: false, default: false
      t.boolean :bodyweight, null: false, default: false
      t.timestamps

      t.index :slug, unique: true
      t.index :muscle_group
    end

    create_table :gym_routines, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :gym_routine_days, id: :uuid do |t|
      t.references :routine, null: false, type: :uuid, foreign_key: {to_table: :gym_routines}
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :gym_routine_exercises, id: :uuid do |t|
      t.references :routine_day, null: false, type: :uuid, foreign_key: {to_table: :gym_routine_days}
      t.references :exercise, null: false, type: :uuid, foreign_key: {to_table: :gym_exercises}
      t.integer :position, null: false, default: 0
      t.integer :target_sets, null: false, default: 3
      t.string :target_reps, default: "5"
      t.decimal :target_weight, precision: 8, scale: 2
      t.integer :target_duration_seconds
      t.string :progression_policy, null: false, default: "linear"
      t.string :warmup
      t.timestamps
    end

    create_table :gym_workouts, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :routine, type: :uuid, foreign_key: {to_table: :gym_routines}
      t.string :status, null: false, default: "active"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.text :notes
      t.timestamps

      t.index [:user_id, :status]
      t.index :started_at
    end

    create_table :gym_workout_sets, id: :uuid do |t|
      t.references :workout, null: false, type: :uuid, foreign_key: {to_table: :gym_workouts}
      t.references :exercise, null: false, type: :uuid, foreign_key: {to_table: :gym_exercises}
      t.integer :position, null: false, default: 0
      t.string :kind, null: false, default: "working"
      t.decimal :weight, precision: 8, scale: 2
      t.integer :reps
      t.integer :duration_seconds
      t.decimal :distance_km, precision: 8, scale: 3
      t.boolean :done, null: false, default: false
      t.timestamps

      t.index [:workout_id, :exercise_id]
    end
  end
end
