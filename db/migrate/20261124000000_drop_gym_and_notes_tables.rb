# frozen_string_literal: true

# Gym and notes features were removed (PR #129). Their data was backed up to
# ~/backups/manual-before-refactor.dump on the production server before this ran.
class DropGymAndNotesTables < ActiveRecord::Migration[8.1]
  TABLES = %w[
    gym_workout_sets gym_workouts gym_schedule_entries gym_routine_exercises
    gym_routine_days gym_routines gym_body_metrics gym_exercises
    note_links notes
  ].freeze

  def up
    TABLES.each { |table| drop_table table, if_exists: true, force: :cascade }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Restore gym/notes data from the pre-refactor pg_dump instead."
  end
end
