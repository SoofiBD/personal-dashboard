#!/bin/bash
# Pre-push checks — run before pushing to ensure CI will pass
set -e

echo ""
echo "═══════════════════════════════════════════"
echo "  🚀 Pre-Push Check Suite"
echo "═══════════════════════════════════════════"
echo ""

echo "🔍 [1/4] Running StandardRB (linter)..."
bundle exec standardrb --no-fix
echo "   ✅ Lint passed"
echo ""

echo "🧪 [2/4] Running tests..."
RAILS_ENV=test bin/rails test
echo "   ✅ Tests passed"
echo ""

echo "🔒 [3/4] Running Brakeman (security)..."
bundle exec brakeman --quiet --no-pager
echo "   ✅ Security scan passed"
echo ""

echo "📦 [4/4] Checking gem vulnerabilities..."
bundle exec bundler-audit check --update
echo "   ✅ No vulnerable gems"
echo ""

echo "═══════════════════════════════════════════"
echo "  ✅ All checks passed! Safe to push."
echo "═══════════════════════════════════════════"
echo ""
