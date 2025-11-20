# MHA Survey Portal

> **Template note:** This README aligns with the CSCE 431 ReadMe template. If any section (installation, deployment, etc.) becomes too complex, we will optionally add a video walkthrough in MS Teams → Turnover → Project Turnover → Documents (no grade impact).
>
> Need even deeper walkthroughs (environment variables, screenshots, deployment runbooks)? Jump into the [project wiki](https://github.com/FaqiangMei/MHA-Survey-Portal/wiki) for extended setup guides before continuing.

## Table of Contents

1. [Project Title & Description](#project-title--description)
2. [Requirements (Internal & External Components)](#requirements-internal--external-components)
3. [External Dependencies](#external-dependencies)
4. [Environmental Variables / Files](#environmental-variables--files)
5. [Installation & Setup](#installation--setup)
6. [Usage](#usage)
7. [Features](#features)
8. [Documentation](#documentation)
9. [Credits & Acknowledgements](#credits--acknowledgements)
10. [Third-Party Libraries](#third-party-libraries)
11. [Contact Information](#contact-information)

## Project Title & Description

**MHA Survey Portal** is a Ruby on Rails application that streamlines the Texas A&M Master of Health Administration (MHA) survey lifecycle. Students complete required assessments, advisors monitor cohorts, and administrators orchestrate the program—each via secure, role-aware dashboards with feedback loops and analytics.

## Requirements (Internal & External Components)

| Layer | Requirements |
| --- | --- |
| **Internal components** | Ruby `3.4.6`, Rails `8.0.3`, Bundler, all gems in [`Gemfile`](Gemfile), Node.js (optional for tooling), Minitest, RuboCop. |
| **External components** | PostgreSQL `14`, Redis (Solid Queue/Cable), Docker Desktop, Git, optional Heroku account for deployment & review apps. |

## External Dependencies

| Dependency | Purpose |
| --- | --- |
| Docker Desktop | Reproducible local + CI stack |
| Heroku CLI | Pipeline & review app management |
| Git / GitHub Desktop | Version control workflows |
| Google Cloud Console | OAuth credentials for TAMU SSO |
| mkcert (optional) | Local HTTPS certificates |

## Environmental Variables / Files

| Variable | Description |
| --- | --- |
| `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` | Override local Postgres settings. |
| `DATABASE_URL` | Full connection string (CI/production). |
| `RAILS_MASTER_KEY` | Unlocks encrypted credentials files. |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `OAUTH_REDIRECT_URI` | Google OAuth client settings. |
| `ENABLE_ROLE_SWITCH` | QA-only impersonation toggle. |
| `PORT` | Custom dev server port (defaults to `3000`). |

Encrypted credentials live in `config/credentials/*.yml.enc`; request `config/master.key` from a maintainer when onboarding.

## Installation & Setup

```bash
git clone https://github.com/FaqiangMei/Health.git
cd Health
```

### Option A – automated

```bash
bin/setup
```

Runs bundle install, prepares the `health_development` database, executes migrations, and seeds demo data.

### Option B – manual

```bash
gem install bundler
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

If you use custom Postgres credentials, set `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_HOST`, and `DATABASE_PORT` (see `config/database.yml`).

➡️ Detailed screenshots and troubleshooting tips live in the wiki’s [Getting Started](https://github.com/FaqiangMei/MHA-Survey-Portal/wiki/Getting-Started) article—use it if you need more context than the quick steps below.

### Deep-dive checklist

1. **Verify toolchain** – `ruby -v` ⇒ `3.4.6`; `psql --version` ⇒ `14.x`. Install via rbenv/asdf/Homebrew/Windows installers as needed.
2. **Create dev DB role** *(one-time)*

   ```sql
   CREATE ROLE dev_user WITH LOGIN PASSWORD 'dev_pass';
   ALTER ROLE dev_user CREATEDB;
   ```

3. **Install gems**

   ```bash
   bundle config set --local path 'vendor/bundle'
   bundle install
   ```

4. **Prepare database**

   ```bash
   bin/rails db:prepare
   bin/rails db:seed
   ```

5. **Launch services** – `bin/dev` (Rails + CSS build) and optional `bin/rails solid_queue:start` for background jobs.
6. **Troubleshoot** – Missing master key? request it. PG auth errors? verify the role. Legacy Webpacker warnings? clear `tmp/` and rerun `bin/setup`.

### Docker workflow

```bash
docker compose run --rm web bin/rails db:prepare db:seed
docker compose up --build
```

- Repository mounts to `/csce431/501_health` in the container for live reloads.
- Run tests with `docker compose run --rm web ruby run_tests.rb`.
- `docker compose down --volumes` resets the DB.
- OneDrive tip: exclude `vendor/bundle` to prevent sync conflicts during builds.

## Usage

- **Local development** – `bin/dev`, browse <http://localhost:3000>, sign in with seeded accounts (see `db/seeds.rb`).
- **Testing** – `ruby run_tests.rb`, `ruby run_tests.rb --type models`, or `docker compose run --rm web ruby run_tests.rb --coverage`.
- **Background jobs** – `bin/rails solid_queue:start` in a second terminal.
- **Deployment** – Heroku review apps + staging pipeline configured via [`app.json`](app.json); promote staging → production through the Heroku dashboard.
- **CI** – GitHub Actions defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) execute RuboCop plus the Minitest suite for every push/PR.

## Features

- **Role-aware dashboards** – tailored Student, Advisor, and Admin experiences with Google OAuth gating.
- **Survey lifecycle management** – build questions, assign by track, collect responses, attach evidence, archive submissions.
- **Feedback & notifications** – advisors review student work, trigger reminders, and view audit trails.
- **Analytics & reporting** – KPI cards, filters, PDF/Excel exports via `Reports::DataAggregator` and `CompositeReportGenerator`.
- **Accessibility controls** – persistent text scaling, high-contrast mode, translation + TTS helpers.
- **Automation** – Solid Queue jobs drive assignment, due, overdue, and completion alerts.

## Documentation

The GitHub Wiki is the authoritative knowledge base:

- [Project Overview](https://github.com/FaqiangMei/MHA-Survey-Portal/wiki/Project-Overview)
- [Architecture](https://github.com/FaqiangMei/MHA-Survey-Portal/wiki/Architecture)
- [Getting Started](https://github.com/FaqiangMei/MHA-Survey-Portal/wiki/Getting-Started)
- [Student / Advisor / Administrator playbooks](https://github.com/FaqiangMei/MHA-Survey-Portal/wiki)
- [System Administration & Deployment](https://github.com/FaqiangMei/MHA-Survey-Portal/wiki/System-Administration)

`/about` in the app links directly to these articles. Update the wiki to keep in-app help accurate.

## Credits & Acknowledgements

- **Program sponsor** – Texas A&M School of Public Health (MHA leadership).
- **Faculty mentors** – Carla Stebbins, Ruoqi Wei, Hye Chung Kum.
- **Engineering team** – CSCE 431 Fall 2025 Health cohort (see git history for contributors).
- **AI contributions** – GitHub Copilot Chat powered by **GPT-5.1-Codex (Preview)** assisted with refactors, documentation wording, and linting suggestions; humans reviewed all commits before merge.

## Third-Party Libraries

- Rails 8, ActiveRecord, ActionCable – core framework.
- Devise + `omniauth-google-oauth2` – authentication & TAMU SSO.
- Tailwind CSS + custom tokens – design system.
- Stimulus + Turbo – interactive components.
- Chart.js + Propshaft – analytics visualization pipeline.
- Solid Queue / Solid Cache / Solid Cable – background jobs & caching.
- WickedPDF + RubyXL – PDF/Excel exports.
- GitHub Copilot Chat (GPT-5.1-Codex Preview) – AI pair-programming resource.

## Contact Information

- **Primary contact**: Tee Li — <rainsuds@tamu.edu>
- **Faculty advisor**: Pauline Wade — <paulinewade@tamu.edu>
- **Issues & pull requests**: please open items directly in this GitHub repository.

Last updated: 2025-11-19
