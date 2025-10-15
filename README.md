# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Developer setup (recommended)

We provide a `bin/setup` helper to get a developer environment ready. It will:

- check `.ruby-version` and print guidance if your Ruby mismatches
- run `bundle install`
- attempt to create and migrate the development DB
- run `db:seed`

Run:

```bash
./bin/setup
```

If your `config/database.yml` references a DB user that doesn't exist (e.g. `user_501_health`), either create that DB user on your Postgres server or set environment variables `DATABASE_USER` and `DATABASE_PASSWORD` before running `bin/setup`.

### Quick manual steps (if you prefer)

1. Install Ruby (rbenv recommended) and set the version from `.ruby-version`.
2. gem install bundler && bundle install
3. Start Postgres (Homebrew on macOS): `brew services start postgresql`
4. Create DB user if needed:

```sql
-- in psql as a superuser
CREATE ROLE user_501_health WITH LOGIN PASSWORD 'password_501_health';
CREATE DATABASE health_app_development OWNER user_501_health;
```

5. Run migrations & seeds:

```bash
bin/rails db:create db:migrate db:seed
```

## Docker (recommended for team reproducibility)

The repository already includes a Tailwind-enabled `docker-compose.yml` with three services:

| service | purpose |
|---------|---------|
| `db`    | Postgres 14 with a bind-mounted volume for persistent data |
| `web`   | Rails application container (serves the app, runs migrations, etc.) |
| `css`   | Lightweight container that runs `bin/rails tailwindcss:watch` to rebuild CSS on the fly |

All services mount the project directory into `/csce431/501_health`, so you can run Rails commands without additional `cd` steps.

### Docker quickstart

Build the image and bring everything online (web + Tailwind watcher + Postgres):

```bash
docker compose up --build web css db
```

You can leave the `css` service running in a separate terminal during development so Tailwind rebuilds instantly whenever you edit view templates or Tailwind source files.

Run one-off Rails commands via compose:

```bash
# Create, migrate, and seed the development database
docker compose run --rm web bin/rails db:prepare db:seed

# Rails console / runner
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails runner "puts Survey.count"

# Execute the test suite (Tailwind assets auto-build before tests boot)
docker compose run --rm web bin/rails test
```

What the seeds add
- A default survey titled "Default Sample Survey" with sample competencies and questions.
- A local test student: `faqiangmei@gmail.com` (track set to `residential`).

Troubleshooting notes
- If seeds abort with an enum validation (e.g. invalid `track`), check `app/models/student.rb` for valid values (`residential`, `executive`).
- If you still see the older built-in copy of the project inside the container (`/rails`), rebuild the web image with `docker compose build web` and restart the stack.

## Heroku review apps & PR previews

For temporary PR deployments, enable [Heroku Review Apps](https://devcenter.heroku.com/articles/github-integration-review-apps). The repository now includes an `app.json` manifest (see below) that automatically provisions a isolated Postgres add-on and runs database migrations after each review app is deployed.

Setup checklist:

1. Create or link a Heroku pipeline to your GitHub repository: `heroku pipelines:create <pipeline-name> --app <staging-app>`.
2. Enable Review Apps in the Heroku dashboard or via CLI: `heroku pipelines:enable-review-app --pipeline <pipeline-name>`.
3. Ensure the pipeline and its review apps share the same `RAILS_MASTER_KEY`: `heroku pipelines:config:set RAILS_MASTER_KEY=$(cat config/master.key) --pipeline <pipeline-name>`.
4. Optional: add any additional env vars (OAuth secrets, etc.) to the pipeline config so every review app inherits them.

Once enabled, each PR will:

- Spin up a dedicated Heroku app with the add-ons listed in `app.json`.
- Run `bundle exec rails db:migrate` automatically after deploy, creating the database schema without manual intervention.
- Destroy itself automatically when the PR is closed (configurable).

### Adding seed data for review apps

If you want sample data in every PR environment, provide a `postdeploy` script in `app.json` (already set to run migrations) and extend it to invoke seeds, e.g. `bundle exec rails db:seed`. Keep seeds idempotent so repeated deploys stay stable.

### Local favicon asset

The layout now serves a TAMU logo from `app/assets/images/tamu-logo.png` as the site favicon. If you update that asset, redeploy so Propshaft re-bundles the new icon.

