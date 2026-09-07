# 🌟 Personal Dashboard

[![Project Status: Active Development](https://img.shields.io/badge/Project%20Status-Active%20Development-brightgreen.svg)](#-project-status--roadmap)
[![Ruby](https://img.shields.io/badge/Ruby-3.3-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-7.2-cc0000.svg)](https://rubyonrails.org/)
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
- [PDF to Markdown](#-pdf-to-markdown)
- [Database Design (ChartDB)](#database-design-chartdb)
- [NAS Files](#nas-files)
- [Environment Configuration](#-environment-configuration)
- [Modular Architecture](#-modular-architecture)
- [Contributing & Development](#-contributing--development)
- [License](#-license)

---

## 💡 Overview & Architecture

The application is engineered as a modular dashboard hub. While the initial focus is **Personal Finance Management**, the core host application is designed to easily plug in new domain modules (notes, reminders, developer tools, AI workflows, etc.) with clean domain boundaries.

```
personal-dashboard/
├── app/                  # Host application (shell layout, core settings, unified navigation)
├── finance_module/       # Finance domain engine (models, controllers, views, migrations)
├── db/                   # Database schemas and global migrations
├── config/               # Rails routing and Caddy gateway configuration
├── modules/chartdb/      # Database schema editor source and Docker build
├── pdf_worker/           # PDF-to-Markdown conversion service
├── nas_worker/           # NAS file service
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

### PDF Editor (Stirling PDF)
- **Integrated workspace:** Open PDF Editor from the hub or PDF module navigation.
- **Local tools:** Edit, merge, split, reorder, convert and compress PDFs using the separate Stirling PDF service.
- **Shared authentication:** The `/pdf-editor/` gateway route requires a dashboard session.

### 🎨 Interface & Experience
- **Obsidian Luxe design system:** Shared color, spacing, typography, motion, and status tokens across the dashboard.
- **Responsive finance views:** Dashboard, transactions, budgets, reports, imports, and settings adapt to compact screens.
- **Accessible interaction states:** Keyboard-friendly controls, focus treatment, reduced-motion support, and semantic labels.
- **Localized UI:** Turkish and English copy share the same component and layout system.

### 📄 PDF to Markdown Workspace
- **Isolated converter:** A dedicated FastAPI worker uses Microsoft MarkItDown and PyMuPDF; it is only reachable from the Rails service network.
- **Deterministic cleanup:** Repeated header/footer removal, line-wrap and hyphen repair, heading synthesis, image extraction, captions, annotations, and validated GFM table extraction.
- **Editable output:** Live Markdown preview, line numbers, find/replace, copy, persistent edits, and image insertion from the extracted asset gallery.
- **Portable export:** The ZIP contains the current Markdown and an `images/` directory with matching relative links; a standalone HTML export embeds extracted images and sanitizes rendered content.

---

## 🔮 Project Status & Roadmap

The project is evolving into an all-in-one personal workspace and life operating system. The following modules and features are actively planned or currently in development:

### 🔐 Authentication & Access Control
- [x] Password-protected login and expiring secure session.
- [x] TOTP multi-factor authentication (MFA) with encrypted-at-rest secrets.
- [x] Role-based access control for multiple users (owner, editor, viewer).
- [x] User profile customizations and localized preferences.

### 📄 PDF Tools & Document Management
- [x] In-browser PDF viewer for stored source documents (annotation tools remain planned).
- [x] PDF editing, splitting, merging, and page re-ordering through Stirling PDF.
- [ ] Receipt and invoice parsing from uploaded PDFs.

### 📝 Notes & Knowledge Base
- [ ] Rich Markdown note-taking workspace with tag support.
- [ ] Fast search, categorization, and quick-capture notes modal.
- [ ] Bi-directional linking between notes, budgets, and tasks.

### ⏰ Smart Reminder & Notification System
- [ ] Scheduled recurring reminders for bill payments, subscriptions, and tasks.
- [ ] In-app notification center and badge alerts.
- [ ] Optional email / webhook / push notifications for upcoming deadlines.

### 🛠️ Developer Tools & Database UI
- [x] ChartDB schema designer with SQL/DBML import, SQL export and JSON backups.
- [ ] Embedded Database UI / Query Inspector for managing records directly.
- [ ] API playground and webhook management console.
- [ ] System health metrics, log monitoring, and cache inspections.

### 🤖 Artificial Intelligence Integrations
- [ ] **AI Financial Advisor:** Automated spending habits analysis, anomaly detection, and savings suggestions.
- [ ] **Smart OCR & Categorization:** Auto-extract transaction details from receipts and photos.
- [ ] **Interactive AI Assistant:** Conversational query interface to ask natural questions about your data (e.g., *"How much did I spend on groceries in July?"*).

---

## 🛠️ Prerequisites

Make sure you have one of the following setups installed on your machine:

- **For Docker setup (Recommended):**
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine (v24+) & Docker Compose (v2+)
- **For Local Native setup:**
  - Ruby 3.3.x
  - Rails 7.2.x
  - PostgreSQL 16+
  - Node.js & npm / yarn (for asset compilation if needed)

---

## 🚀 Installation & Getting Started

### Option A: Docker Compose (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/personal-dashboard.git
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

Production uses a separate Compose definition so the local HTTP stack is never reused as an internet-facing deployment. Copy `.env.production.example` to `.env.production`, set a DNS-resolvable `DASHBOARD_DOMAIN`, strong database credentials, and `RAILS_MASTER_KEY`; then run:

```bash
docker compose --env-file .env.production -f compose.production.yaml up --build -d
```

Caddy obtains and renews TLS certificates for the configured domain. Do not expose the development `compose.yaml` stack beyond `127.0.0.1`.

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

This starts Rails only. ChartDB, Stirling PDF and document conversion require their
separate services; use the Compose setup for the complete module system and authenticated gateway routes.

1. **Clone and enter the directory:**
   ```bash
   git clone https://github.com/your-username/personal-dashboard.git
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

## 📄 PDF to Markdown

Open **PDF Dokümanları** from the Finance navigation to upload a PDF (maximum 25 MB and 250 pages). The source PDF is retained in the owner-scoped conversion record so the same document can be reprocessed with different settings.

The upload and reprocess forms support image extraction (50–500 px threshold), header/footer removal, caption binding, annotation extraction mode, YAML frontmatter, line-wrap repair, and table detection. Conversion runs through Solid Queue so the web request returns immediately and queued work survives web-process restarts. The worker is intentionally not published on a host port.

To review old conversion records without deleting anything, run `docker compose --env-file .env.local run --rm web bin/rails document_conversions:purge[90]`. The task is dry-run by default; add `CONFIRM=yes` only after reviewing the count to permanently remove those records, their source PDFs, and extracted assets.

Run the worker’s deterministic tests with:

```bash
docker compose --env-file .env.local build pdf-worker
docker run --rm personal-dashboard-pdf-worker python -m unittest discover -s tests -v
```

---

## ⚙️ Environment Configuration

The following variables can be customized in `.env.local`:

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

---

## 🏛️ Modular Architecture

This project follows a clean **modular domain architecture**:
- **Domain Decoupling:** New domain features (e.g., `notes_module/`, `tasks_module/`, `ai_module/`) can be added independently without cluttering core host logic.
- **Isolated Migrations & Views:** Each module maintains its own controllers, views, data models, and migrations while sharing host layout and styling tokens.
- **Service modules:** ChartDB and Stirling PDF run as internal services behind the authenticated Caddy gateway; Rails supplies their dashboard landing pages and navigation.
- **Storage boundaries:** Finance and document records use server storage. ChartDB diagrams use browser storage and require separate JSON backups. ChartDB analytics and cloud promotion are disabled.

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
its [GNU AGPL v3 license](modules/chartdb/LICENSE). No top-level `LICENSE` file is currently included in this repository.

## NAS Files

The NAS module is available only to the account owner. See the [NAS guide](nas_worker/README.md)
for setup, local configuration and operation limits.

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
