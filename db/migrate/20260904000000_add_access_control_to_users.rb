class AddAccessControlToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :role, :string, null: false, default: "owner"
    add_column :users, :email, :string
    add_column :users, :locale, :string, null: false, default: "tr"
    add_column :users, :mfa_secret, :text
    add_column :users, :mfa_enabled, :boolean, null: false, default: false
    add_column :users, :mfa_confirmed_at, :datetime

    add_index :users, :role
    add_index :users, :email, unique: true
  end
end
