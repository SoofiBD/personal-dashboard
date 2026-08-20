# 🔄 CI/CD & Contribution Guide

This document describes the automated workflows, branch strategy, and contribution process for the Personal Dashboard project.

---

## Table of Contents

- [Automated Workflows Overview](#automated-workflows-overview)
- [What Happens When You Open a PR](#what-happens-when-you-open-a-pr)
- [Branch Strategy](#branch-strategy)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [CI Pipeline Details](#ci-pipeline-details)
- [Security Practices](#security-practices)
- [Local Development Checks](#local-development-checks)
- [Troubleshooting CI Failures](#troubleshooting-ci-failures)

---

## Automated Workflows Overview

The project uses **GitHub Actions** with 4 workflow files:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| [`ci.yml`](.github/workflows/ci.yml) | PR to `main`, push to `main` | Tests, linting, security scanning |
| [`auto-label.yml`](.github/workflows/auto-label.yml) | PR opened/updated | Auto-labels PRs by changed files |
| [`dependency-review.yml`](.github/workflows/dependency-review.yml) | PR with Gemfile changes | Scans new dependencies for vulnerabilities |

### CI Pipeline Architecture

```
PR Opened / Push to main
        │
        ▼
┌───────────────────────────────────────────────────┐
│                    CI Pipeline                     │
│                                                    │
│  ┌─────────┐   ┌─────────┐   ┌──────────────┐    │
│  │  Lint &  │   │  Tests  │   │   Security   │    │
│  │ Analysis │   │         │   │    Checks    │    │
│  └────┬─────┘   └────┬────┘   └──────┬───────┘    │
│       │              │               │             │
│       ▼              ▼               ▼             │
│  StandardRB     Rails test      Brakeman           │
│  Brakeman       PostgreSQL      TruffleHog         │
│  bundler-audit  Parallel run    Bundler Audit       │
│                                                    │
│       └──────────┬───────────────┘                 │
│                  ▼                                  │
│         ┌──────────────┐                           │
│         │  PR Status   │                           │
│         │    Gate      │                           │
│         └──────┬───────┘                           │
│                │                                   │
│         ALL PASS → ✅ Mergeable                     │
│         ANY FAIL → ❌ Blocked                       │
└───────────────────────────────────────────────────┘
```

---

## What Happens When You Open a PR

1. **Lint & Static Analysis** (~2 min)
   - **StandardRB** checks Ruby code style and formatting
   - **Brakeman** scans for security vulnerabilities (SQL injection, XSS, etc.)
   - **Bundler Audit** checks gems for known CVEs

2. **Tests** (~5 min)
   - Spins up a PostgreSQL 16 service container
   - Runs database migrations
   - Executes the full test suite with parallelization
   - On failure: uploads screenshots and test logs as artifacts

3. **Security Checks** (~3 min)
   - **TruffleHog** scans for accidentally committed secrets (API keys, passwords)
   - **Brakeman** generates a detailed JSON security report
   - Report is uploaded as a downloadable artifact

4. **Dependency Review** (only when Gemfile changes)
   - Scans added/updated gems for known vulnerabilities
   - Posts a summary comment on the PR
   - Fails if any high-severity vulnerability is found

5. **Auto Labeling**
   - Automatically adds labels like `module: finance`, `type: migration`, etc.

6. **PR Status Gate**
   - Final check that aggregates all job results
   - PR can only be merged if ALL checks pass

---

## Branch Strategy

```
main (protected)
  │
  ├── feature/yearly-budget-view     ← New features
  ├── fix/budget-copy-calculation     ← Bug fixes
  ├── chore/update-dependencies       ← Maintenance
  └── docs/update-readme              ← Documentation
```

### Rules

| Rule | Details |
|------|---------|
| **Protected branch** | `main` should be protected — no direct pushes |
| **Branch naming** | Use prefixes: `feature/`, `fix/`, `chore/`, `docs/` |
| **Short-lived branches** | Merge or close within 1-2 weeks |
| **Up-to-date** | Rebase on `main` before merging |

### Recommended GitHub Branch Protection Settings

Go to **Settings → Branches → Add rule** for `main`:

- [x] Require a pull request before merging
- [x] Require status checks to pass before merging
  - Required checks: `PR Status Check`
- [x] Require branches to be up to date before merging
- [x] Require conversation resolution before merging
- [ ] Require signed commits (optional, recommended)
- [x] Do not allow bypassing the above settings

---

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/) for clear, machine-readable history:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | When to Use | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(budget): add yearly budget view` |
| `fix` | Bug fix | `fix(transactions): correct date filter query` |
| `refactor` | Code change (no feature/fix) | `refactor(models): extract balance calculator` |
| `test` | Adding/updating tests | `test(budget): add allocation copy tests` |
| `docs` | Documentation only | `docs: update CI guide` |
| `chore` | Maintenance, deps, CI | `chore: update Rails to 7.1.5` |
| `style` | Formatting, no logic change | `style: fix StandardRB offenses` |
| `perf` | Performance improvement | `perf(dashboard): cache monthly queries` |

### Scopes

Use the module or feature area: `budget`, `transactions`, `goals`, `dashboard`, `accounts`, `categories`, `purchases`, `ci`, `deps`.

---

## Pull Request Process

### Before Opening a PR

```bash
# 1. Run tests locally
RAILS_ENV=test bin/rails test

# 2. Run linter
bundle exec standardrb --fix

# 3. Run security scanner
bundle exec brakeman --quiet

# 4. Check for vulnerable gems
bundle exec bundler-audit check --update
```

### PR Template

Create PRs with this structure:

```markdown
## What does this PR do?
Brief description of the change.

## Related Issue
Closes #XX

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactor
- [ ] Documentation
- [ ] CI/CD

## Checklist
- [ ] Tests pass locally (`bin/rails test`)
- [ ] StandardRB passes (`bundle exec standardrb`)
- [ ] Brakeman has no new warnings
- [ ] Migration is reversible (if applicable)
- [ ] I have updated relevant documentation
```

### Review Process

1. **Author** opens PR with description and links to the issue
2. **CI** runs automatically — all checks must pass ✅
3. **Reviewer** checks:
   - Code quality and Rails conventions
   - Test coverage for new features
   - Security implications (especially for finance data)
   - Database migration safety
4. **Author** addresses feedback
5. **Merge** via squash merge to keep history clean

---

## CI Pipeline Details

### Tools & Their Purpose

| Tool | Purpose | Config |
|------|---------|--------|
| **StandardRB** | Ruby linting (based on RuboCop with sane defaults) | `.standard.yml` (optional) |
| **Brakeman** | Static analysis for Rails security vulnerabilities | Auto-detects Rails app |
| **Bundler Audit** | Checks Gemfile.lock against Ruby Advisory Database | No config needed |
| **TruffleHog** | Detects committed secrets and credentials | Auto-scans git history |
| **Dependency Review** | GitHub-native check for vulnerable dependencies | Built-in |

### Service Containers

The test job spins up a real **PostgreSQL 16** container, matching the production database. This ensures:
- Migration compatibility
- Real query execution (no SQLite differences)
- Constraint and index validation

### Concurrency Control

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

If you push multiple commits quickly, only the latest run continues — saving CI minutes and avoiding queue buildup.

---

## Security Practices

### What the CI Checks

| Check | What It Catches |
|-------|----------------|
| **Brakeman** | SQL injection, XSS, CSRF, mass assignment, open redirects, unsafe redirects, file access |
| **Bundler Audit** | Known CVEs in gem dependencies |
| **TruffleHog** | API keys, database passwords, tokens accidentally committed |
| **Dependency Review** | Risky new dependencies added in a PR |

### Finance Module Security Rules

Since this is a **personal finance application**, extra care is needed:

1. **Never log financial data** — amounts, account names, or balances should not appear in logs
2. **Always scope queries to `user_id`** — every finance query must filter by the current user
3. **Validate ownership on associations** — foreign keys from the client must be verified (e.g., `account.user_id == current_user.id`)
4. **No mass assignment of `user_id`** — use `current_user.transactions.build(params)` pattern
5. **Sanitize all user input** — especially in search/filter features
6. **Use `decimal(14,2)` for money** — never use floats for financial calculations

### Secrets Management

| ✅ Do | ❌ Don't |
|-------|----------|
| Use GitHub Secrets for CI env vars | Commit `.env.local` or any secrets |
| Use `ENV.fetch("VAR")` with defaults | Hardcode credentials in source code |
| Rotate secrets periodically | Share secrets via chat/email |
| Add secrets to `.gitignore` | Use production credentials in CI |

---

## Local Development Checks

### Quick Pre-Push Script

Add this to your workflow — run before pushing:

```bash
#!/bin/bash
# scripts/pre-push-check.sh

set -e

echo "🔍 Running StandardRB..."
bundle exec standardrb --no-fix

echo "🧪 Running tests..."
RAILS_ENV=test bin/rails test

echo "🔒 Running Brakeman..."
bundle exec brakeman --quiet --no-pager

echo "📦 Checking gem vulnerabilities..."
bundle exec bundler-audit check --update

echo ""
echo "✅ All checks passed! Safe to push."
```

### Docker-Based Testing

```bash
# Run tests inside Docker (matches CI environment closely)
docker compose exec -T \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/personal_dashboard_test \
  web ./bin/rails test
```

---

## Troubleshooting CI Failures

### StandardRB Failures

```bash
# See all offenses
bundle exec standardrb

# Auto-fix what's possible
bundle exec standardrb --fix
```

### Brakeman Warnings

```bash
# Run locally with details
bundle exec brakeman

# Ignore a false positive (document why!)
# Add to config/brakeman.ignore
```

### Test Failures

```bash
# Run a specific test file
bin/rails test test/models/personal_finance/transaction_test.rb

# Run a specific test by line number
bin/rails test test/models/personal_finance/transaction_test.rb:15

# Run with verbose output
bin/rails test --verbose
```

### Bundler Audit Failures

```bash
# See details about vulnerable gems
bundle exec bundler-audit check

# Update the vulnerability database
bundle exec bundler-audit update

# Update the vulnerable gem
bundle update <gem_name>
```

---

## Future Improvements

As the project grows, consider adding:

| Improvement | When | Priority |
|-------------|------|----------|
| **Code coverage reporting** (SimpleCov) | When test count > 50 | Medium |
| **System tests** (Capybara + headless Chrome) | When UI stabilizes | Medium |
| **Performance tests** | When user base grows | Low |
| **Staging auto-deploy** | When staging server exists | Medium |
| **Database migration lint** (strong_migrations) | When production DB exists | High |
| **PR size limit warning** | When team grows | Low |
| **CODEOWNERS file** | When contributors > 2 | Medium |
