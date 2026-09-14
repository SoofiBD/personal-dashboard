class CreateLearning < ActiveRecord::Migration[7.2]
  def change
    create_table :learning_items do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.string :track, null: false, default: "interview"
      t.string :kind, null: false, default: "topic"
      t.string :status, null: false, default: "planned"
      t.string :source_key
      t.string :resource_key
      t.string :difficulty, null: false, default: "medium"
      t.integer :position, null: false, default: 0
      t.integer :confidence, null: false, default: 0
      t.integer :estimated_minutes, null: false, default: 30
      t.date :target_on
      t.date :review_on
      t.text :notes
      t.timestamps
    end
    add_index :learning_items, [:user_id, :source_key], unique: true
    add_index :learning_items, [:user_id, :track, :status]
    create_table :learning_attempts do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: {to_table: :learning_items}
      t.string :outcome, null: false
      t.integer :minutes, null: false
      t.integer :confidence, null: false
      t.text :reflection
      t.timestamps
    end
  end
end
