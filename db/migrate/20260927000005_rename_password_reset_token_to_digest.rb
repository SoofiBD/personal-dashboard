class RenamePasswordResetTokenToDigest < ActiveRecord::Migration[7.2]
  def change
    rename_column :users, :password_reset_token, :password_reset_digest
  end
end
