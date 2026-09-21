#!/bin/sh
# Rebuild the Paperling-derived Markdown editor bundle and copy it into the
# Rails asset pipeline (committed to vendor/). Requires node/npm on the host
# (the Docker image has no node toolchain).
set -eu
cd "$(dirname "$0")"
npm ci --no-audit --no-fund
npm run build
echo "OK: vendor/assets/javascripts/md-editor/ updated - commit the result."
