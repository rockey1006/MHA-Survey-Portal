# README

## Introduction

### Application Description

Health Survey Platform is a Rails 8 application supporting the Texas A&M Health Master of Health Administration (MHA) program. The system lets administrators and advisors run executive and residential surveys, collect student responses, and analyze feedback across competencies.

## Requirements

This codebase is actively developed on the following toolchain:

- Ruby – `3.4.6`
- Rails – `8.0.3`
- RubyGems – see [`Gemfile`](Gemfile)
- PostgreSQL – `14` (local Docker image ships with 14)
- Node.js / Yarn – optional (importmap handles JS by default)
- Docker Desktop – latest stable
- Git – latest stable

## External Deps

- Docker Desktop – <https://www.docker.com/products/docker-desktop>
- Heroku CLI – <https://devcenter.heroku.com/articles/heroku-cli>
- Git – <https://git-scm.com/book/en/v2/Getting-Started-Installing-Git>
- GitHub Desktop (optional) – <https://desktop.github.com/>

## Installation

Clone the repository from GitHub:

```bash
git clone https://github.com/FaqiangMei/Health.git
cd Health
```

### Option A – automated setup

```bash
bin/setup
```

The setup script installs gems, prepares the `health_development` database, runs migrations, and seeds the sample data.

### Option B – manual setup

```bash
gem install bundler
bundle install

# Create, migrate, and seed
bin/rails db:create db:migrate db:seed

# Start the server on http://localhost:3000
bin/dev
```

If your local Postgres credentials differ from the defaults (`dev_user` / `dev_pass`), export `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_HOST`, and `DATABASE_PORT` before running the commands above. See `config/database.yml` for all supported environment variables.

### Detailed local deployment walkthrough

1. **Verify prerequisites**
	- `ruby -v` should report `3.4.6`. If not, install via `rbenv`, `asdf`, or RubyInstaller (Windows) and restart your shell.
	- Ensure PostgreSQL 14+ is running. On macOS with Homebrew: `brew services start postgresql@14`. On Windows, use the PostgreSQL App or run the Windows service `postgresql-x64-14`.
	- Optional but recommended: install `direnv` or use shell profiles to persist database environment variables.

2. **Create the application database role (only once per machine)**
	```sql
	-- from psql with a superuser account (e.g., `psql -U postgres`)
	CREATE ROLE dev_user WITH LOGIN PASSWORD 'dev_pass';
	ALTER ROLE dev_user CREATEDB;
	```
	If you prefer different credentials, update `config/database.yml` or export matching environment variables before the next step.

3. **Install Ruby gems**
	```bash
	bundle config set --local path 'vendor/bundle'
	bundle install
	```
	The local path keeps gems inside the project, which helps when switching Ruby versions.

4. **Prepare the database**
	```bash
	bin/rails db:prepare
	bin/rails db:seed
	```
	`db:prepare` handles creation and migrations automatically; rerun it whenever migrations change.

5. **Inspect seed output**
	- Admin accounts are listed in the console as they are created.
	- A residential and an executive survey are generated with all categories and questions. Confirm via `bin/rails console`:
	  ```ruby
	  Survey.pluck(:title, :questions_count)
	  Student.group(:track).count
	  ```

6. **Launch the server**
	```bash
	bin/dev
	```
	Visit <http://localhost:3000>. You can sign in using any seeded user (e.g., `admin1@tamu.edu` / password printed during seeding) or create a new account via the UI.

7. **Background jobs (optional)**
	- The app uses Solid Queue for async work. For local experimentation: `bin/rails solid_queue:start` in a separate terminal.
	- Solid Cache and Solid Cable run inline in development, so no extra daemons are required.

8. **Troubleshooting**
	- *PG::ConnectionBad (password authentication failed)*: double-check the credentials used to create `dev_user` or set `DATABASE_USER` / `DATABASE_PASSWORD` to match an existing role.
	- *Missing master key*: copy `config/master.key` from a teammate or request it from the repo maintainer. Without it you cannot decrypt credentials.
	- *Webpacker/Node errors*: this project uses import maps; if you see leftover Webpacker references, clear `tmp/` and rerun `bin/setup`.

## Tests

An automated Minitest suite (with helpers in `run_tests.rb`) is available. Run all suites with:

```bash
ruby run_tests.rb
```

Useful examples:

- `ruby run_tests.rb --type models`
- `ruby run_tests.rb --coverage`
- `docker compose run --rm web ruby run_tests.rb`

## Execute Code

### Local machine

```bash
bin/dev
```

Visit <http://localhost:3000> to use the app.

### With Docker (recommended for consistency)

```bash
# Prepare the database and seed data
docker compose run --rm web bin/rails db:prepare db:seed

# Start the stack
docker compose up --build
```

The `web` service mounts the repository at `/csce431/501_health`, so edits on the host reflect inside the container immediately. Use `docker compose run --rm web bin/rails console` for an interactive console session.

> **OneDrive tip:** When working from a synced folder, exclude `vendor/bundle` to avoid "cloud operation was unsuccessful" errors during Docker builds.

#### Detailed Docker workflow

1. **Prerequisites**
	- Docker Desktop running (WSL2 backend on Windows).
	- No other service bound to ports `3000` (Rails) or `5433` (Postgres).

2. **First-time setup**
	```powershell
	# Windows PowerShell
	cd path\to\Health
	docker compose run --rm web bin/rails db:prepare db:seed
	```
	```bash
	# macOS / Linux
	cd /path/to/Health
	docker compose run --rm web bin/rails db:prepare db:seed
	```
	This builds the `web` image, creates the `health_app_development` database with credentials defined in `docker-compose.yml`, runs migrations, and loads all seed data (admins, students, surveys, responses).

3. **Start the stack**
	```powershell
	# Windows PowerShell
	docker compose up --build
	```
	```bash
	# macOS / Linux
	docker compose up --build
	```
	- Keep this command running to stream logs from Rails and Postgres.
	- Visit <http://localhost:3000>.
	- Use `Ctrl+C` to stop both containers. For background mode, run `docker compose up -d` and stop later with `docker compose down`.

4. **Common maintenance commands**
	```powershell
	# Windows PowerShell
	docker compose run --rm web bin/rails console
	docker compose run --rm web ruby run_tests.rb
	docker compose run --rm web bash
	```
	```bash
	# macOS / Linux
	docker compose run --rm web bin/rails console
	docker compose run --rm web ruby run_tests.rb
	docker compose run --rm web bash
	```

5. **Troubleshooting**
	- *Build errors referencing OneDrive*: ensure `vendor/bundle` is excluded from sync (already in `.dockerignore`).
	- *Database connection refused*: confirm no local Postgres is occupying port `5433`, or change the mapped port in `docker-compose.yml`.
	- *Schema stale after pulling changes*: rerun `docker compose run --rm web bin/rails db:migrate`.
	- *Need a clean database*: `docker compose down --volumes` removes the database volume; rerun the first-time setup afterwards.

## Environmental Variables / Files

- `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` – database connection overrides
- `DATABASE_URL` – full connection string (used in production and CI)
- `RAILS_MASTER_KEY` – enables encrypted credentials
- `PORT` – web server port override (default `3000`)

Credentials are encrypted via Rails’ built-in key management. Review <https://medium.com/craft-academy/encrypted-credentials-in-ruby-on-rails-9db1f36d8570> for a refresher on how encrypted secrets work.

## Seed Data

`db/seeds.rb` resets core tables, provisions seven administrator accounts, creates executive and residential surveys with categories and questions, and generates `SurveyResponse` / `QuestionResponse` shells for every seeded student. The script is idempotent and can be run multiple times safely.

## Deployment

Heroku review apps and staging deployments are managed via [`app.json`](app.json) and the pipeline workflow below:

1. Create `main`, `test`, and (optional) `dev` branches locally.
2. Add a `Procfile` (already included) with `web: bundle exec puma -C config/puma.rb` to run migrations on deploy.
3. Ensure a root route exists in `config/routes.rb` (the dashboard is configured by default).
4. Push the branch to GitHub and enable Heroku Review Apps for pull requests.
5. Connect the staging app to the `main` branch with automatic deploys enabled.
6. For each feature branch: open a PR into `test`, verify the review app build, merge the PR, and promote staging → production from the Heroku dashboard.

Remember to set `RAILS_MASTER_KEY` and any third-party credentials on the Heroku pipeline so every app instance can decrypt credentials.

## CI/CD

GitHub Actions run linting, security scans, and tests on every push and pull request. See [`.github/workflows/ci.yml`](.github/workflows/ci.yml) for the complete pipeline.

## Support

Active development is maintained by the TAMU Health team. For questions or lab assistance, contact Tee Li at <rainsuds@tamu.edu>.

## Extra Helps

- For deeper Rails lab guidance, email Pauline Wade at <paulinewade@tamu.edu>.
 - Future enhancements include generalizing the survey engine for other student organizations.

## Google Sign-in (OAuth) — third-party credentials setup

This project supports third-party login via Google (used by admin/advisors/students). Below are step-by-step notes to create credentials and integrate them with Devise + OmniAuth.

1) Create OAuth credentials in Google Cloud Console

- Go to https://console.cloud.google.com/apis/credentials and create a new OAuth 2.0 Client ID.
- Choose **Web application** and add authorized origins and redirect URIs. Example local values:
	- Authorized JavaScript origins: `http://localhost:3000`
	- Authorized redirect URIs: `http://localhost:3000/users/auth/google_oauth2/callback`
- Save the **Client ID** and **Client secret**; you'll need them as environment variables.

2) Gem & Devise/OmniAuth configuration

- Ensure `omniauth-google-oauth2` is in the `Gemfile` (the project may already include it):

```ruby
# Gemfile
gem 'omniauth-google-oauth2'
```

- Configure Devise to use OmniAuth (example `config/initializers/devise.rb`):

```ruby
config.omniauth :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {
	scope: 'email,profile',
	prompt: 'select_account',
	access_type: 'offline'
}
```

- Update your `User` model to support OmniAuth callbacks (example method):

```ruby
def self.from_omniauth(access_token)
	data = access_token.info
	user = User.where(email: data['email']).first

	# Create the user if it doesn't exist
	unless user
		user = User.create(
			email: data['email'],
			name: data['name'],
			password: Devise.friendly_token[0,20]
		)
	end
	user
end
```

3) Environment variables

Set these env vars locally or in Docker/CI/Heroku:

```bash
export GOOGLE_CLIENT_ID=your-google-client-id
export GOOGLE_CLIENT_SECRET=your-google-client-secret
export OAUTH_REDIRECT_URI=http://localhost:3000/users/auth/google_oauth2/callback
```

In Docker, add the env vars to `docker-compose.yml` or use an override file for local development.

4) Routes & Callbacks

- Ensure Devise routes support OmniAuth callbacks (e.g., `devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }`).
- Implement the `Users::OmniauthCallbacksController` to call `User.from_omniauth` and handle sign-in/registration logic.

5) Heroku / production

- Set the same `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in Heroku config vars or your production environment manager.
- Add the production redirect URI (e.g., `https://your-app.herokuapp.com/users/auth/google_oauth2/callback`) in the Google Cloud Console OAuth client configuration.

6) Testing & troubleshooting

- Common issues:
	- "Invalid redirect URI": make sure the exact callback URL is added to the OAuth client config (scheme, hostname, and path must match).
	- Sign-in returns to sign-in page: check flash messages and logs for `OmniAuth` errors; enable `omniauth.logger = Rails.logger` in an initializer for debugging.
	- Email already exists: handle merge or conflict scenarios in your `from_omniauth` method.

7) Advanced: additional scopes and offline refresh tokens

- If you need long-lived access (for Background API calls to Google on behalf of a user) add `access_type: 'offline'` and handle refresh tokens securely.

---

Last updated: 2025-10-20
