class RenameMfaSecretCiphertext < ActiveRecord::Migration[7.1]
  def up
    return unless column_exists?(:users, :mfa_secret_ciphertext)

    rename_column :users, :mfa_secret_ciphertext, :mfa_secret
  end

  def down
    return unless column_exists?(:users, :mfa_secret)

    rename_column :users, :mfa_secret, :mfa_secret_ciphertext
  end
end
