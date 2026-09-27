class InvalidateLegacyPasswordResetTokens < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE users SET password_reset_digest = NULL, password_reset_sent_at = NULL WHERE password_reset_digest IS NOT NULL"
  end

  def down
    # Plaintext reset tokens must never be restored.
  end
end
