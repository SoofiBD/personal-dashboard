# ChartDB dashboard module

Based on ChartDB 1.20.1; the [GNU AGPL v3 license](LICENSE) is preserved.

This React application runs as a separate internal Compose service, like Stirling PDF.
Open Dashboard → Database Design → Open designer (`/database_tools`).
The action cards open new-diagram creation, SQL/DBML import, and SQL export.
Import/export waits until a diagram is created or opened; JSON and image exports
are available from the editor menu. Caddy authenticates every
`/database-editor/*` request using the Rails session. No host port is exposed.
`/database-editor/config.js` is served by Rails with no-store headers and provides
the authenticated account ID for the browser IndexedDB namespace.

Diagrams live in browser IndexedDB, not PostgreSQL or dashboard backups. Export
JSON to back up or transfer diagrams. Account namespaces prevent accidental mixing,
but browser storage is not a security boundary: use separate browser profiles on
shared devices. Existing open tabs retain their in-memory diagrams after logout.

Analytics and ChartDB Cloud promotion are disabled. No shared AI key is embedded.
The editor designs schemas and generates SQL; it does not execute SQL or create servers.

## Development

From the dashboard root:

```sh
docker compose --env-file .env.local up -d --build chartdb gateway
```

Production uses `compose.production.yaml` and `.env.production` with the same paths.
Both gateway configurations must keep the Rails config.js handler before the editor handler.
Build runs upstream ESLint, TypeScript and Vite checks. Source and lockfile remain here
for reproducible local builds; upstream CI, contribution files and standalone entrypoint
were removed because the dashboard owns deployment and authentication.

Bundled examples, template galleries, their datasets and preview images are removed.
Database logos and import help images remain part of the editor.
