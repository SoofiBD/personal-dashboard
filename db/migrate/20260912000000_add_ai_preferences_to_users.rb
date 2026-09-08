class AddAiPreferencesToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :ai_provider, :string, null: false, default: "jan_local"
    add_column :users, :ai_model, :string
  end
end
