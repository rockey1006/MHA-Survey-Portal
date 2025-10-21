---
# Health — README

This repository contains the Health Professions Rails application used for the CSCE431 project. This README is a curated, step-by-step guide to get a developer up and running and to run tests and CI locally.

Table of contents
- Requirements
- Quick start (Docker)
- Local development (non-Docker)
- Database setup & seeds
- Running the app
- Running tests & coverage
- Useful developer tasks
- Troubleshooting
- Contributing

Requirements
-----------

- Ruby: the project uses the Ruby version in `.ruby-version` (use rbenv or rvm)
- Bundler: gem install bundler
- PostgreSQL: required for development and test DBs (if not using Docker)
- Docker & Docker Compose (recommended) for reproducible local environments

Quick start (recommended — Docker)
---------------------------------

These steps will bring up the app, the database, and a Tailwind CSS watcher.

1. Build and start services (web, db, css watcher):

```powershell
docker compose up --build web css db
```

2. Prepare the database (run once):

```powershell
docker compose run --rm web bin/rails db:prepare db:seed
```

3. Open the app in the browser at http://localhost:3000 (default Rails port)

Useful one-off commands (via Docker):

```powershell
# Rails console
docker compose run --rm web bin/rails console

# Execute tests
docker compose run --rm web bin/rails test

# Run a single test file
docker compose run --rm web bin/rails test test/controllers/feedbacks_controller_test.rb
```

Local development (without Docker)
---------------------------------

1. Install Ruby (matching `.ruby-version`) and Bundler.
2. Install gems:

```powershell
gem install bundler
bundle install
```

3. Setup PostgreSQL and create a DB user if needed (example SQL shown in `bin/setup`).
4. Prepare the DB locally:

```powershell
bin/rails db:create db:migrate db:seed
```

Database setup & seeds
----------------------

- `bin/setup` will try to create and migrate the development DB and run seeds. Use it for a quick bootstrap.
- If your `config/database.yml` references a DB user that doesn't exist, either create the role in Postgres or set `DATABASE_USER` and `DATABASE_PASSWORD` env vars.
- The seeds add a sample survey and at least one test student and admin/advisor accounts useful for development. Seeds are intended to be idempotent.

Running the app
---------------

Start the Rails server (Docker):

```powershell
docker compose run --rm -p 3000:3000 web bin/rails server -b 0.0.0.0
```

Or locally:

```powershell
bin/rails server
```

Running tests & coverage
------------------------

The repository includes a `run_tests.rb` helper that wraps common test commands and optionally runs coverage via SimpleCov.

Basic test commands (Docker):

```powershell
# Run all tests
docker compose run --rm web bin/rails test

# Run tests with the custom runner
docker compose run --rm web ruby run_tests.rb

# Run with coverage
docker compose run --rm web ruby run_tests.rb -c
```

If you run tests locally without Docker, ensure dependencies like Tailwind assets are present or the test runner may build them as needed.

Useful developer tasks
----------------------

- Rebuild Docker images: `docker compose build web`
- Recreate DB from scratch: `bin/rails db:drop db:create db:migrate db:seed`
- Run a single test: `bin/rails test test/models/my_model_test.rb`
- Start a one-off shell inside the web container: `docker compose run --rm web /bin/bash`

Troubleshooting
---------------

- Seeds fail with enum validation: check valid enum values in `app/models/student.rb` (e.g. `residential`, `executive`).
- Tailwind assets not found when running tests: ensure the `css` service (Tailwind watcher) is running or allow the test runner to build assets on-demand.
- Devise sign-in issues in tests: include `Devise::Test::IntegrationHelpers` in Integration tests and use `sign_in users(:advisor)` (fixtures) or create a test user.

Contributing
------------

1. Fork the repository and create a feature branch.
2. Run the full test suite and ensure all tests pass.
3. Open a PR with a clear description of the changes and any migration or seeding notes.

---
Last updated: 2025-10-20

Planned / future features
-------------------------

We track planned and proposed features in `FUTURE_FEATURES.md`. If you have a proposal, add a section there following the provided template so it can be prioritized and scheduled.



