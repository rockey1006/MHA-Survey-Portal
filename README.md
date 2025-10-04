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

If you prefer Docker so every developer gets the same environment, add a simple `docker-compose.yml` with a Postgres service and the app. Example (minimal):

```yaml
version: '3.8'
services:
	db:
		image: postgres:14
		environment:
			POSTGRES_USER: dev_user
			POSTGRES_PASSWORD: dev_pass
			POSTGRES_DB: health_app_development
		ports:
			- "5433:5432"
		volumes:
			- db-data:/var/lib/postgresql/data
	web:
		build: .
		command: bash -lc "bundle install && bin/rails db:create db:migrate db:seed && bin/rails s -b 0.0.0.0"
		volumes:
			- .:/app
		ports:
			- "3000:3000"
		depends_on:
			- db
volumes:
	db-data:
```

Start with:

```bash
docker compose up --build
```

This approach ensures everyone runs the same DB and Ruby environment in containers and avoids touching shared/production databases.

### Docker quickstart (project-specific)

The repository includes a `docker-compose.yml` that mounts the repository into the web container. The compose file sets the web service working directory to the mounted path so you don't need to `cd` inside the container before running Rails commands.

Recommended commands (from your host shell):

Create the DB, run migrations and seed default data:
```bash
docker-compose run --rm web bin/rails db:create db:migrate db:seed
```

Run the app (build first if you changed Dockerfile/gems):
```bash
docker-compose up -d --build
```

Run the rails console or runners without cd:
```bash
docker-compose run --rm web bin/rails console
docker-compose run --rm web bin/rails runner "puts Survey.count"
```

What the seeds add
- A default survey titled "Default Sample Survey" with sample competencies and questions.
- A local test student: `faqiangmei@gmail.com` (track set to `residential`).

Troubleshooting notes
- If seeds abort with an enum validation (e.g. invalid `track`), check `app/models/student.rb` for valid values (`residential`, `executive`).
- If you still see the older built-in copy of the project inside the container (`/rails`), rebuild the web image and restart with `docker-compose up -d --build` to ensure the compose `working_dir` change is active.

If you'd like, I can remove the obsolete top-level `version:` key from `docker-compose.yml` to suppress the startup warning.

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

