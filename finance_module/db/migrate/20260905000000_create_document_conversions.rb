class CreateDocumentConversions < ActiveRecord::Migration[7.2]
  def change
    create_table :document_conversions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true, index: true
      t.string :source_filename, null: false, limit: 255
      t.string :status, null: false, default: "pending", limit: 24
      t.text :custom_notes
      t.text :markdown_content
      t.jsonb :processing_stats, null: false, default: {}
      t.text :error_message
      t.datetime :completed_at
      t.timestamps
    end

    add_index :document_conversions, %i[user_id created_at]
    add_check_constraint :document_conversions,
      "status IN ('pending', 'processing', 'completed', 'failed')",
      name: "document_conversions_status_valid"
  end
end
