#!/bin/bash -e

# Load secrets from Docker secret files
for secret in nas_api_token nas_password; do
  secret_file="/run/secrets/${secret}"
  if [ -f "$secret_file" ]; then
    export "${secret^^}"="$(cat "$secret_file" | tr -d '\n')"
  fi
done

exec "$@"