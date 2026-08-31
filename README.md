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
├── config/               # Rails routing, engines, and configuration
└── compose.yaml          # Containerized development & production stack
```

---

## ✨ Current Features

### 💰 Personal Finance Engine (`finance_module`)
- **Interactive Financial Dashboard:** Overview of total balance, monthly income, expenses, and net cash flow.
- **Budget Tracking & Management:** Set category budgets, monitor live progress with dynamic visual progress bars, and track remaining allowances.
- **Transactions & Accounts:** Record and categorize expenses/incomes across bank accounts, cash, and credit cards.
- **Category Analytics:** Clear insights into spending distribution and category breakdowns.

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
- [ ] PDF editing, splitting, merging, and page re-ordering.
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
   docker compose up --build
   ```
   *(To run containers in the background as daemons, use `docker compose up --build -d`)*

4. **Provision or rotate the dashboard password:**
   ```bash
   docker compose exec web ./bin/rails dashboard:credentials:set
   ```

5. **Access the dashboard:**
   Open your browser and navigate to:
   ```
   http://localhost:3000/finance
   ```
   *Migrations and initial database setup run automatically upon container boot.*

6. **Stopping the containers:**
   ```bash
   docker compose down
   ```
   *(To reset everything including database volumes, run `docker compose down -v`)*

---

### Option B: Local Machine Setup

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
   Navigate to `http://localhost:3000/finance`.

---

## 🧪 Running Tests

Run the comprehensive test suite to ensure system integrity:

### Inside Docker:
```bash
docker compose exec -T \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgresql://personal_dashboard:local-development-password@db:5432/personal_dashboard_test \
  web ./bin/rails test
```

### Local Environment:
```bash
RAILS_ENV=test bin/rails test
```

## 📄 PDF to Markdown

Open **PDF Dokümanları** from the Finance navigation to upload a PDF (maximum 25 MB and 250 pages). The source PDF is retained in the owner-scoped conversion record so the same document can be reprocessed with different settings.

The upload and reprocess forms support image extraction (50–500 px threshold), header/footer removal, caption binding, annotation extraction mode, YAML frontmatter, line-wrap repair, and table detection. Conversion runs through Active Job so the web request returns immediately; the development setup uses Rails’ async adapter. Configure a durable adapter such as Solid Queue before deploying where process restarts must not lose queued work. The worker is intentionally not published on a host port.

To review old conversion records without deleting anything, run `docker compose run --rm web bin/rails document_conversions:purge[90]`. The task is dry-run by default; add `CONFIRM=yes` only after reviewing the count to permanently remove those records, their source PDFs, and extracted assets.

Run the worker’s deterministic tests with:

```bash
docker compose build pdf-worker
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
- **Data Privacy & Control:** 100% self-hosted with no external telemetry or proprietary locks on your personal data.

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

Distributed under the **MIT License**. See `LICENSE` for more information.
