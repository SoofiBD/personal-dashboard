class CreateAiActions < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_actions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :action_type, null: false
      t.string :status, null: false, default: "pending"
      t.string :summary, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.datetime :expires_at, null: false
      t.datetime :executed_at
      t.string :error_message
      t.timestamps
      t.index [:user_id, :status]
    end
  end
end
