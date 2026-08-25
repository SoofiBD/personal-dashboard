class AddAuthenticationVersionToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :authentication_version, :integer, null: false, default: 0
  end
end
