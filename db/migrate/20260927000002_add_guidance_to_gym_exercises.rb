# frozen_string_literal: true

class AddGuidanceToGymExercises < ActiveRecord::Migration[7.2]
  def change
    add_column :gym_exercises, :instructions, :text
    add_column :gym_exercises, :safety_notes, :text
    add_column :gym_exercises, :demo_url, :string
  end
end
