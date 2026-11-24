#!/bin/sh
# Rebuild the Paperling-derived Markdown editor bundle and copy it into the
# Rails asset pipeline (committed to vendor/). Requires node/npm on the host
# (the Docker image has no node toolchain).
set -eu
cd "$(dirname "$0")"
npm ci --no-audit --no-fund
npm run build
# Mermaid is loaded lazily by the browser, so ship its prebuilt UMD file next to the bundle.
cp node_modules/mermaid/dist/mermaid.min.js ../../vendor/assets/javascripts/md-editor/mermaid.min.js
# Vite emits the CSS next to the JS; the pipeline serves it from vendor/assets/stylesheets.
mv ../../vendor/assets/javascripts/md-editor/md-editor.css ../../vendor/assets/stylesheets/md-editor/md-editor.css
echo "OK: vendor/assets/javascripts/md-editor/ updated - commit the result."
