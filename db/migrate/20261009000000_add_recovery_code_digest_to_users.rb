class AddRecoveryCodeDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :recovery_code_digest, :string
    add_index :users, :recovery_code_digest, unique: true
  end
end
