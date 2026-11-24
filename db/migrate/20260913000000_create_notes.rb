class CreateNotes < ActiveRecord::Migration[7.2]
  def change
    create_table :notes, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :title, null: false, limit: 160
      t.text :body, null: false, default: ""
      t.text :tag_list, null: false, default: ""
      t.boolean :pinned, null: false, default: false
      t.timestamps
    end
    add_index :notes, [:user_id, :updated_at]

    create_table :note_links do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :source_note, null: false, type: :uuid, foreign_key: {to_table: :notes}
      t.references :target_note, null: false, type: :uuid, foreign_key: {to_table: :notes}
      t.timestamps
    end
    add_index :note_links, [:source_note_id, :target_note_id], unique: true
  end
end
