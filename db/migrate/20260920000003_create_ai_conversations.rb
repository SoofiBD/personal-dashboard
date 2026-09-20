class CreateAiConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_conversations, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false
      t.text :content
      t.jsonb :metadata, default: {}
      t.timestamps
      t.index [:user_id, :created_at]
    end
  end
end