# frozen_string_literal: true

class AddGymTracking < ActiveRecord::Migration[7.2]
  def change
    create_table :gym_body_metrics, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.date :recorded_on, null: false
      t.decimal :weight_kg, precision: 6, scale: 2, null: false
      t.text :note
      t.timestamps

      t.index [:user_id, :recorded_on], unique: true
    end

    create_table :gym_schedule_entries, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :routine_day, null: false, type: :uuid, foreign_key: {to_table: :gym_routine_days}
      t.date :scheduled_on, null: false
      t.timestamps

      t.index [:user_id, :scheduled_on]
      t.index [:user_id, :routine_day_id, :scheduled_on], unique: true, name: "index_gym_schedule_entries_unique_day"
    end
  end
end
