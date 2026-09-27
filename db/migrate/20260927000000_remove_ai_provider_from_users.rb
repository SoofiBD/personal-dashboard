class RemoveAiProviderFromUsers < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE users SET ai_model = NULL WHERE ai_provider <> 'gemini'"
    remove_column :users, :ai_provider
  end

  def down
    add_column :users, :ai_provider, :string, null: false, default: "gemini"
  end
end
