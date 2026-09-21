class CreateAiMemories < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_memories, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :category, null: false
      t.string :key, null: false
      t.text :value, null: false, limit: 500
      t.timestamps
      t.index [:user_id, :category, :key], unique: true
      t.index [:user_id, :category]
    end
  end
end
