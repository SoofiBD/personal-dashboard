# Deploy

Production = Oracle VM, Docker Compose, code from GitHub `main`. Only bash, git and docker compose are used.

## Layout on the server

Fixed app dir `/home/ubuntu/personal-dashboard`, a git checkout:

- `.env.production` (untracked) – env, includes `COMPOSE_PROJECT_NAME`
- `secrets/*.txt` (untracked) – `rails_master_key`, `pdf_worker_api_key`, `postgres_password`
- backups in `~/backups/pre-<sha>-<time>.dump` (14 newest kept)

All data lives in named volumes (`<project>_postgres_data`, `_storage_data`, `_stirling_*`, `_caddy_*`). Compose derives the volume prefix from the **project name**. A different project name means empty volumes, including an empty DB. `bin/deploy` refuses to run if `<project>_postgres_data` does not exist (override for a fresh server only: `FIRST_INSTALL=1`).

## Server checklist (read-only, do first)

```bash
docker compose ls                                  # project name + config file path of the running stack
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
docker volume ls                                   # note <project>_postgres_data, _storage_data, ...
cd /home/ubuntu/personal-dashboard-deploy-*/ && git rev-parse HEAD 2>/dev/null; pwd   # running commit (or read the dir name)
ls -la /home/ubuntu/personal-dashboard/            # .env.production, secrets/, is it a git repo?
df -h / /var/lib/docker; free -h; nproc            # disk, RAM, CPUs
docker stats --no-stream                           # real memory per container
sudo ls -l /etc/sudoers.d/                         # leftover 90-ocarun-recovery?
cd /home/ubuntu/personal-dashboard && git remote -v  # server must be able to fetch from GitHub
```

Memory: limits are web 1.5g, jobs 1g, pdf-worker 1.5g, stirling 2g, db 1g, gateway 256m = 7.25g worst case. The production VM (2026-11) has 1 OCPU / 5.8 GB and actual use is about 1.7 GB, so the limits are caps that are never all reached at once. Builds on 1 CPU take several minutes; the old containers keep serving until `== up`.

If `/etc/sudoers.d/90-ocarun-recovery` exists and the recovery is over, remove it (`sudo rm`) after confirming it is the temporary one. Passwordless sudo for a recovery user is a standing hole.

## One-time migration to the fixed dir

No `down`, no `-v`, no volume commands. Each step says what to verify.

1. **Find the project name** from the checklist (`docker compose ls`, or the volume prefix: `docker volume ls | grep postgres_data`). Likely `personal-dashboard-deploy-a8a82f0`.
2. **Manual backup first** (old dir, old stack still running):
   ```bash
   mkdir -p ~/backups && cd /home/ubuntu/personal-dashboard-deploy-a8a82f0
   docker compose --env-file ../personal-dashboard/.env.production -f compose.production.yaml exec -T db \
     sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > ~/backups/manual-before-migration.dump
   ls -l ~/backups/manual-before-migration.dump        # not empty
   ```
   Adjust the env-file path to wherever the old stack reads it. Copy the dump off the server too (`scp`).
3. **Make the fixed dir a checkout** (ignored `.env.production` and `secrets/` are untouched):
   ```bash
   cd /home/ubuntu/personal-dashboard
   git init -q && git remote add origin https://github.com/SoofiBD/personal-dashboard.git
   git fetch origin main && git checkout --detach FETCH_HEAD
   ls bin/deploy .env.production secrets/              # all present
   ```
   If the dir is already a repo, skip `init`/`remote`. If checkout complains about overwriting files, stop and look; do not use `-f`.
4. **Pin the project name**: add `COMPOSE_PROJECT_NAME=<name from step 1>` to `.env.production`. Verify:
   ```bash
   docker compose --env-file .env.production -f compose.production.yaml config | head -1   # name: <same name>
   docker volume inspect <name>_postgres_data >/dev/null && echo volume found
   ```
5. **Deploy**: `bin/deploy main`. Compose sees the same project and recreates the containers from the new dir (same volumes). Expect a short downtime. It backs up, builds, migrates, waits for health and runs `bin/verify_production`.
6. **Verify**: log in on the site, open a document, check recent data is present, `docker volume ls` shows no new `*_postgres_data`.
7. Keep the old per-commit dir for a week, then delete it (`rm -rf` on the dir only; it holds no data).
8. Optional later: gym/notes tables are still in the DB on purpose; drop them only after a fresh dump.

If step 5 fails before `== up`, the old stack is still running untouched. If the new stack starts on an empty DB anyway: `docker compose ... stop web jobs`, fix the project name, rerun `bin/deploy`. Nothing is lost, the real volume was never modified.

## Normal deploy

```bash
ssh oracle-finance 'cd /home/ubuntu/personal-dashboard && bin/deploy main'   # or a tag / sha
```

Merge to `main` first and wait for CI. `bin/deploy` stops on the first error (`set -euo pipefail`).

## Rollback

- Code only (usual case): `bin/deploy <previous-sha>` (printed at the end of every deploy). It takes a new backup and rebuilds.
- Migrations are forward-only and the previous code usually still works with the new schema. If a migration damaged data, restore the dump printed by `bin/deploy`:
  ```bash
  dc='docker compose --env-file .env.production -f compose.production.yaml'
  $dc stop web jobs
  $dc exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner' < ~/backups/<file>.dump
  bin/deploy <previous-sha>
  ```
  Restoring replaces everything written since the dump. Uploaded files (`storage_data`) are not in the dump.

## Secrets

Only on the server, in the app dir, never in git: `.env.production` and `secrets/*.txt` (see `.env.production.example`). `bin/deploy` never prints them.

## Checks before shipping changes to this setup

`bash -n bin/deploy && shellcheck bin/deploy`, `docker compose --env-file .env.production.example -f compose.production.yaml config -q`, `bin/rails test`.
