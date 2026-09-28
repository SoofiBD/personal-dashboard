require "digest"

# MFA seeds are encrypted before they reach the database. Deployments can supply
# dedicated values; local installations derive stable keys from secret_key_base.
secret_key_base = ENV.fetch("SECRET_KEY_BASE") { Rails.application.secret_key_base }
derived_key = ->(purpose) { Digest::SHA256.digest("#{secret_key_base}:#{purpose}").byteslice(0, 16) }

Rails.application.config.active_record.encryption.primary_key = ENV.fetch("DASHBOARD_MFA_ENCRYPTION_KEY") { derived_key.call("mfa-primary") }
Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("DASHBOARD_MFA_DETERMINISTIC_KEY") { derived_key.call("mfa-deterministic") }
Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("DASHBOARD_MFA_KEY_DERIVATION_SALT") { derived_key.call("mfa-salt") }
