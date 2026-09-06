# NAS module

The workspace hub links to `/nas` for the dashboard owner. Rails applies the existing login/session/MFA flow and CSRF protection; editors and viewers cannot access any NAS route. The Python adapter has no published host port and requires a separate bearer credential. NAS credentials never reach browser HTML, JavaScript or application logs.

## Local setup

1. Copy `nas_worker/.env.example` to `.env.nas.local` in the project root. Set host, share and a dedicated SMB account restricted to the intended share. Generate a random service token (at least 32 characters).
2. Set `NAS_WORKER_URL=http://nas-worker:8000` and the same `NAS_API_TOKEN` in `.env.local` for Rails. Keep `.env.nas.local` readable only by its owner (`chmod 600`).
3. Run `docker compose --env-file .env.local up -d --build nas-worker web`.
4. Open the dashboard as owner and select NAS. The worker requires LAN/VPN reachability to TCP 445 and SMB2 support. NAS authentication is checked on a real folder request, not by the worker liveness check.

Production: add `-f compose.nas.yaml` to the existing production Compose command and supply the two Rails environment variables through the existing deployment secret mechanism. The adapter must stay private; use TLS if the adapter is on a different host. Do not expose SMB to the Internet.

The default `compose.yaml` includes the NAS service, so ordinary `docker compose up` and `docker compose down` manage it together with the dashboard. The NAS environment file is optional for fresh checkouts; without credentials, NAS requests remain disabled. `down` preserves data volumes unless `--volumes` is explicitly supplied.

## Behavior and limits

- One directory listing per request; no recursive whole-share scans. Summaries cover immediate children only, not disk capacity or total NAS usage.
- Case-insensitive name filtering, name/size/date sorting, folders first, 100 items per page. SMB still enumerates the selected directory before pagination; extremely large individual directories remain expensive.
- Upload/download limit: 256 MiB. Downloads spool to temporary files on both sides, with a size limit even if a file grows during transfer. Uploads use file streams. No automatic retry of mutations.
- Existing names reject upload. This is a preflight conflict check, not an atomic lock against other SMB clients; avoid concurrent writers to the same path.
- Delete requires the exact name. Wildcards, traversal, SMB alternate streams and root deletion are rejected. Directories must be empty. Deletion is permanent; configure NAS snapshots separately.
- No recursive ZIP or recursive deletion endpoint: the legacy implementation could exhaust memory and silently omit failed files. Large archive workflows should run directly on the NAS.
- SMB2 is required; this adapter does not provide SMB3 transport encryption. Run only on a trusted LAN/VPN with a dedicated least-privilege account.
- CPU temperature, RAID/SMART and physical free space are not invented from SMB directory sizes; these require a vendor-specific management API.

## Credential recovery and publishing

The migration saved recovered legacy login values in `.private/nas-recovery.json` with mode 0600, and moved old TLS material there. This directory and all real NAS environment files are excluded from Git and Docker build contexts. Read this local file to recover the old password; do not paste its contents into issues or logs. Existing secrets have not been changed on the NAS.

The legacy sibling folder is retired in favor of this module. If it was previously published elsewhere, removing local values does not remove GitHub history: rotate both old passwords and replace the old TLS key. No remote history is rewritten automatically.

Before publication run `python3 scripts/check-nas-secrets.py` and the existing pre-push suite. The check inspects Git-visible working files, including tracked ignored files, blocks private material, checks recovered values when the local recovery file exists, and never prints values. It is an extra guard, not a general secret scanner or proof that all past commits are clean.

## Tests

`docker compose --env-file .env.local run --rm --no-deps -v "$PWD/nas_worker/tests:/app/tests:ro" nas-worker python -m unittest discover -s tests`

`docker compose --env-file .env.local exec -T web env RAILS_ENV=test bin/rails test test/controllers/nas_controller_test.rb test/controllers/home_controller_test.rb`

Transfer behavior follows the [pysmb API](https://pysmb.readthedocs.io/en/latest/api/smb_SMBConnection.html) and [Flask upload limits](https://flask.palletsprojects.com/en/stable/patterns/fileuploads/).
