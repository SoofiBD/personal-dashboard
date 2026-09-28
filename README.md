# 🌟 Personal Dashboard

[![Project Status: Active Development](https://img.shields.io/badge/Project%20Status-Active%20Development-brightgreen.svg)](#-project-status--roadmap)
[![Ruby](https://img.shields.io/badge/Ruby-3.3-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1-cc0000.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg)](https://www.docker.com/)

A modern, self-hosted, modular personal dashboard application built with **Ruby on Rails** and **PostgreSQL**. Designed for privacy, extensibility, and unified control over personal productivity and financial life.

> 🚀 **Note:** This project is under **active development**. New modules, UI enhancements, and integrations are continuously being developed and shipped.

---

## 📑 Table of Contents

- [Overview & Architecture](#-overview--architecture)
- [Current Features](#-current-features)
- [Project Status & Roadmap (Upcoming Features)](#-project-status--roadmap)
- [Prerequisites](#-prerequisites)
- [Installation & Getting Started](#-installation--getting-started)
  - [Option A: Docker Compose (Recommended)](#option-a-docker-compose-recommended)
  - [Option B: Local Machine Setup](#option-b-local-machine-setup)
- [Running Tests](#-running-tests)
- [Database Design (ChartDB)](#database-design-chartdb)
- [Environment Configuration](#-environment-configuration)
- [Modular Architecture](#-modular-architecture)
- [Contributing & Development](#-contributing--development)
- [License](#-license)

---

## 💡 Overview & Architecture

The application is engineered as a modular dashboard hub. While the initial focus is **Personal Finance Management**, the core host application is designed to easily plug in new domain modules (notes, developer tools, AI workflows, etc.) with clean domain boundaries.

```
personal-dashboard/
├── app/                  # Host application (shell layout, core settings, unified navigation)
├── finance_module/       # Finance domain engine (models, controllers, views, migrations)
├── notes_module/         # Markdown notes, tags, and note links
├── learning_module/      # Learning plans, practice, and review tracking
├── gym_module/           # Training plans, workouts, and body metrics
├── pdf_worker/           # Private PDF extraction and image processing
├── db/                   # Database schemas and global migrations
├── config/               # Rails routing and Caddy gateway configuration
├── modules/chartdb/      # Database schema editor source and Docker build
├── compose.yaml          # Local development stack
└── compose.production.yaml # Production HTTPS stack
```

---

## ✨ Current Features

### 💰 Personal Finance Engine (`finance_module`)
- **Interactive Financial Dashboard:** Overview of total balance, monthly income, expenses, and net cash flow.
- **Budget Tracking & Management:** Set category budgets, monitor live progress with dynamic visual progress bars, and track remaining allowances.
- **Transactions & Accounts:** Record and categorize expenses/incomes across bank accounts, cash, and credit cards.
- **Category Analytics:** Clear insights into spending distribution and category breakdowns.

### Database Design (ChartDB)
- **Dashboard module:** Open Database Design from the workspace hub or module switcher.
- **Schema workflows:** Create a diagram, import SQL/DBML, and export SQL through the three action cards. ChartDB also supports JSON backups and diagram image exports.
- **Session-protected editor:** Caddy serves `/database-editor/` through dashboard authentication; ChartDB has no published host port.
- **Browser storage:** Diagrams are stored in IndexedDB, scoped to the dashboard account, and must be backed up through ChartDB.
- **Trimmed distribution:** Bundled examples, template galleries, datasets and preview images are removed. Editor icons, database logos and import help images remain.

### 📝 Notes & Knowledge Base
- **Local Markdown notes:** Write and keep notes in PostgreSQL without a separate editor service or client-side database.
- **Search and tags:** Search titles, content, and tags; pin important notes and filter by tag.
- **Bi-directional links between notes:** Use `[[Another note title]]` in a note to create an outgoing link and automatic backlink after saving.
- **Interactive visualization:** Open **Bağlantı grafiği** to inspect note nodes and their relationships without adding a visualization library. Search, tag filters, pinned/linked filters, radial/grid layouts, zoom/pan/reset, degree-aware node sizing, relationship highlighting, and a keyboard-accessible note detail panel are included.
- **Per-user privacy:** Notes and links are scoped to the signed-in account; viewers may read but cannot change them.

### 🤖 Interactive AI Workspace
- **Gemini-backed assistant:** Uses the signed-in user's finance, notes, learning, gym, and document context for grounded analysis and planning.
- **Reviewable actions:** Proposed changes remain pending until an owner or editor reviews the exact payload and approves it. Viewers cannot change workspace records through the assistant.
- **Program planning:** Turns user-provided training routines or weekly/monthly learning plans into proposals; approval is required before records are created.
- **Boundaries:** Dashboard data is accessed through user-scoped tools. The assistant does not autonomously move money, manage credentials, or execute arbitrary commands.

### 📚 Learning and Training
- **Learning:** Track plans, practice attempts, review dates, and unfinished work.
- **Gym:** Maintain routines and weekly schedules, log sets and body weight, and review volume, streak, muscle-readiness, and exercise guidance.

### PDF extraction and OpenDataLoader integration

Uploaded PDFs stay on the dashboard's private storage. The Rails conversion job sends at most 25 MB / 250 pages to the internal, authenticated PDF worker. OpenDataLoader PDF 2.5.11 runs locally in that worker with Java 21 to extract Markdown, including reading order and tables. The existing PyMuPDF path still extracts images and annotations and serves as a fallback if OpenDataLoader cannot process a particular file. `processing_stats.parser` records which path produced the result. Files created for OpenDataLoader are isolated per request and removed when parsing ends; no external parsing API is used.

Deployment and next integration steps:

1. Rebuild the PDF worker image and verify a digital PDF with headings, columns, and tables. Production reserves up to 1.5 GB of RAM for the worker. Monitor parse time, fallback rate, and memory before increasing document limits.
2. Scanned/image-only PDFs need OCR. The current local OpenDataLoader mode does **not** OCR them and returns a clear error when no text is found. If scan support is needed, add a separate private OpenDataLoader hybrid/OCR service, enable it only for scan/complex-page triage, and size/test its larger model dependencies independently. Do not expose it publicly.
3. For page-grounded AI answers, request OpenDataLoader JSON alongside Markdown and store bounded element/page references separately from conversion stats. The assistant should cite source pages, treat extracted text as untrusted input, and keep document edits behind the existing action-confirmation flow. Add regression samples for invoices, Turkish text, multi-column reports, tables, and scans before enabling OCR in production.

---

## 🔮 Project Status & Roadmap

The project is evolving into an all-in-one personal workspace and life operating system. The following modules and features are actively planned or currently in development:

### 🔐 Authentication & Access Control
- [x] Password-protected login and expiring secure session.
- [x] TOTP multi-factor authentication (MFA) with encrypted-at-rest secrets.
- [x] Role-based access control for multiple users (owner, editor, viewer).
- [x] User profile customizations and localized preferences.
- [x] Email password reset when SMTP is configured; reset tokens are stored as digests and redacted from gateway access logs.

### 📝 Notes & Knowledge Base
- [x] Markdown note-taking workspace with tag support.
- [x] Fast title/content/tag search and pinning.
- [x] Bi-directional links between notes.

### 🛠️ Developer Tools & Database UI
- [x] ChartDB schema designer with SQL/DBML import, SQL export and JSON backups.

### 🤖 Artificial Intelligence Integrations
- [x] **Interactive AI Assistant:** User-scoped analysis and confirmation-gated proposals for finance, notes, learning, gym, and documents.
- [ ] **Automated Financial Monitoring:** Proactive anomaly detection and savings alerts without a prompt.
- [ ] **Smart OCR & Categorization:** Auto-extract transaction details from receipts and photos.

---

## 🛠️ Prerequisites

Make sure you have one of the following setups installed on your machine:

- **For Docker setup (Recommended):**
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine (v24+) & Docker Compose (v2+)
- **For Local Native setup:**
  - Ruby 3.3.x
  - Rails 8.1.x
  - PostgreSQL 16+
  - Node.js & npm / yarn (for asset compilation if needed)

---

## 🚀 Installation & Getting Started

### Option A: Docker Compose (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/SoofiBD/personal-dashboard.git
   cd personal-dashboard
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env.local
   ```
   *Open `.env.local`, set a secure URI-safe `POSTGRES_PASSWORD`, and personalize your settings. Do not persist the dashboard login password in this file.*

3. **Build and start the application:**
   ```bash
   docker compose --env-file .env.local up --build
   ```
   *(To run containers in the background as daemons, use `docker compose --env-file .env.local up --build -d`)*

4. **Provision or rotate the dashboard password:**
   ```bash
   docker compose --env-file .env.local exec web ./bin/rails dashboard:credentials:set
   ```

5. **Access the dashboard:**
   Open your browser and navigate to:
   ```
   http://localhost:3000/
   ```
   *Migrations and initial database setup run automatically upon container boot.*

### Production HTTPS

Production uses a separate Compose definition so the local HTTP stack is never reused as an internet-facing deployment. Set a DNS-resolvable `DASHBOARD_DOMAIN`, matching database credentials, and the required Git-ignored `secrets/*.txt` files. Stirling PDF uses the authenticated Rails session through Caddy and does not require a second password. Configure SMTP if web password reset is needed; then run:

```bash
docker compose --env-file .env.production -f compose.production.yaml up --build -d
```

Caddy obtains and renews TLS certificates for the configured domain. Do not expose the development `compose.yaml` stack beyond `127.0.0.1`.
NAS management is outside this repository; this stack does not expose NAS access.

Keep deployment runbooks and infrastructure notes outside the repository. Do not commit production credentials, private keys, recovery material, or host-specific configuration.

#### Production data-protection requirements

- Place the Docker host and its `postgres_data` and `storage_data` volumes on encrypted storage; these volumes contain financial records, uploaded PDFs, and extracted images.
- Back up both volumes to encrypted off-host storage and test a restore at least quarterly.
- Set `DOCUMENT_RETENTION_DAYS` (default: `90`) to the shortest retention period that meets your needs. The production job service permanently purges older PDF conversions and their attachments every day.
- Collect the gateway access logs and Rails `security_audit` JSON events. Alert on repeated `login_failed` / `mfa_challenge_failed` events, any `user_created` or `user_updated` event, and unusually frequent document-conversion or financial-data export events.

6. **Stopping the containers:**
   ```bash
   docker compose --env-file .env.local down
   ```
   *(To reset everything including database volumes, run `docker compose --env-file .env.local down -v`)*

---

### Option B: Local Machine Setup

This starts Rails only. ChartDB requires its separate service; use the Compose setup for the complete module system and authenticated gateway routes.

1. **Clone and enter the directory:**
   ```bash
   git clone https://github.com/SoofiBD/personal-dashboard.git
   cd personal-dashboard
   ```

2. **Install Ruby dependencies:**
   ```bash
   bundle install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.example .env.local
   ```

4. **Prepare database & run migrations:**
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed # (if seed data is available)
   ```

5. **Provision or rotate the dashboard password:**
   ```bash
   bin/rails dashboard:credentials:set
   ```

6. **Start the Rails development server:**
   ```bash
   bin/rails server -b 127.0.0.1 -p 3000
   ```

7. **Visit the app:**
   Navigate to `http://localhost:3000/`.

---

## 🧪 Running Tests

Run the comprehensive test suite to ensure system integrity:

### Inside Docker:
```bash
docker compose --env-file .env.local exec -T \
  -e RAILS_ENV=test \
  web ./bin/rails test
```

### Local Environment:
```bash
RAILS_ENV=test bin/rails test
```

---

## ⚙️ Environment Configuration

Use `.env.local` for development and Git-ignored `.env.production` for deployment. Production-only settings are marked below:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `DASHBOARD_OWNER_NAME` | Display name of the dashboard owner | `Personal Dashboard` |
| `DASHBOARD_OWNER_EMAIL` | Optional owner login identifier | None; legacy password-only owner login remains supported |
| `DASHBOARD_MFA_ENCRYPTION_KEY` | Optional 32-character deployment key for encrypted MFA seeds | Derived from Rails secret key base |
| `DASHBOARD_AUTH_PASSWORD` | Optional non-interactive input for the credential provisioning task; do not persist it | None; minimum 16 characters |
| `DASHBOARD_CURRENCY` | Default currency code (e.g., `USD`, `EUR`, `TRY`) | `TRY` |
| `DASHBOARD_TIME_ZONE` | Time zone used for scheduling and timestamps | `Europe/Istanbul` |
| `POSTGRES_DB` | PostgreSQL database name | `personal_dashboard_development` |
| `POSTGRES_USER` | PostgreSQL username | `personal_dashboard` |
| `POSTGRES_PASSWORD` | PostgreSQL password; required and never defaulted | None; generate a random value |
| `GEMINI_API_KEY` | Google Gemini API anahtarı; AI Asistan için zorunlu | None |
| `DASHBOARD_DOMAIN` | Public HTTPS hostname | Required in production |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM` | Outbound mail for password reset | Optional in production; web reset is unavailable without a complete configuration |

### AI Assistant

Set `GEMINI_API_KEY` in the runtime environment, then open **Yapay Zekâ Asistanı** to work with the authenticated user's finance, notes, learning, gym, and document data. Each user can choose a Gemini model under **Sağlayıcı ve model**. Actions are proposals until reviewed and approved in the dashboard; never put API keys in the browser or ChartDB configuration.

---

## 🏛️ Modular Architecture

This project follows a clean **modular domain architecture**:
- **Domain Decoupling:** New domain features (e.g., `notes_module/`, `tasks_module/`, `ai_module/`) can be added independently without cluttering core host logic.
- **Isolated Migrations & Views:** Each module maintains its own controllers, views, data models, and migrations while sharing host layout and styling tokens.
- **Service modules:** ChartDB runs as an internal service behind the authenticated Caddy gateway; Rails supplies its dashboard landing page and navigation.
- **Storage boundaries:** Finance and document records use server storage. ChartDB diagrams use browser storage and require separate JSON backups. ChartDB analytics and cloud promotion are disabled.
- **Knowledge-graph tooling:** Graphify is an optional, local developer tool; it is not bundled in the runtime image. See [Graphify development guide](docs/graphify.md).

---

## 🤝 Contributing & Development

Contributions, feature requests, and feedback are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Third-party components retain their own licenses. The bundled ChartDB source includes
its [GNU AGPL v3 license](modules/chartdb/LICENSE). The Markdown editor bundle
(`frontend/md-editor`, served from `vendor/assets/javascripts/md-editor/`) is derived from
[Paperling](https://github.com/Razee4315/Paperling) (Apache-2.0); see
[frontend/md-editor/NOTICE.md](frontend/md-editor/NOTICE.md). No top-level `LICENSE` file is currently included in this repository.

## Database Design (ChartDB)

Open **Veritabanı Tasarımı / Database Design** from the hub or module menu, or visit
`http://localhost:3000/database_tools`. The editor runs at `/database-editor/`.

| Dashboard card | Action |
| :--- | :--- |
| Visual schema design | Opens the new-diagram dialog. |
| Import schemas | Opens SQL/DBML import after a diagram is created or opened. |
| Export SQL and backups | Opens SQL export after a diagram is created or opened. Use the editor menu for JSON backups and image exports. |

ChartDB designs schemas and generates SQL. It does not execute SQL, manage live database
records or provision database servers.

### Storage and backups

Diagrams stay in the current browser's IndexedDB, with separate namespaces for dashboard
accounts. They do not automatically sync between devices and are **not included in dashboard
or PostgreSQL backups**. Export JSON in ChartDB to back up or transfer your work. Clearing
browser site data removes these local diagrams. Use separate browser profiles on shared devices;
account namespaces prevent accidental mixing but are not a browser-storage security boundary.

### Build and update

Run from the dashboard root:

```bash
docker compose --env-file .env.local up -d --build chartdb gateway
```

Production uses the same module in `compose.production.yaml`:

```bash
docker compose --env-file .env.production -f compose.production.yaml up -d --build chartdb gateway
```

The image build runs ESLint, TypeScript and Vite. The Node build step allows a 4 GB heap;
ensure the build host has sufficient memory. The running ChartDB service has a separate
256 MB memory limit.

The distribution excludes the upstream example gallery, template gallery, sample datasets
and associated preview images. Required editor assets are retained. Analytics and ChartDB
Cloud promotion are disabled, and no shared AI API key is embedded.

For implementation details, see [modules/chartdb/README.md](modules/chartdb/README.md).
