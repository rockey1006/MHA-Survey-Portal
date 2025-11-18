# Getting Started

Follow these steps to stand up the Health application locally, seed it with data, and verify your environment. Two workflows are supported: Docker Compose (recommended) and a native Ruby toolchain.

## Prerequisites

- Git
- Docker Desktop (includes Docker Compose v2)
- (Optional) Ruby 3.4.x, Node 20+, Yarn, and PostgreSQL 14 if you prefer a native setup
- Access to the project secrets (`config/master.key`, `config/credentials.yml.enc`, and any `.env` files maintained by the team)

## 1. Clone the repository

```sh
git clone https://github.com/FaqiangMei/MHA-Survey-Portal.git
cd MHA-Survey-Portal
```

## 2. Configure secrets & environment variables

1. Ensure `config/master.key` is present (request from an existing maintainer if needed).
2. Decrypt or copy `config/credentials.yml.enc` (contains Google OAuth and other secrets).
3. Optional `.env` overrides can be placed at the project root; Rails reads from credentials by default.
4. Common environment variables:
   - `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` (development defaults live in `config/environments/development.rb`).
   - `ENABLE_ROLE_SWITCH=1` to expose the role switcher outside development/test.
   - `JOB_CONCURRENCY` to tune background job workers (see `config/queue.yml`).

## 3. Choose a setup workflow

### Option A – Docker Compose (recommended)

1. Build and start the stack:

   ```sh
   docker compose up --build
   ```

   The `web` service starts Rails, the `css` service watches Tailwind builds, and PostgreSQL runs in the `db` service (port `5433` on the host).

2. In a separate terminal, run database setup the first time:

   ```sh
   docker compose exec web bin/rails db:prepare
   docker compose exec web bin/rails db:seed
   ```

   `db:prepare` handles create + migrate; `db:seed` loads surveys, sample users, and synthetic responses.

3. Rails will be available at [http://localhost:3000](http://localhost:3000). Stop services with `Ctrl+C` or `docker compose down`.

### Option B – Native Ruby environment

1. Install Ruby 3.4.x (see `.ruby-version`) and Bundler 2.5.x.
2. Install system packages: PostgreSQL 14, Node.js ≥ 20, Yarn (or pnpm), JavaScript build tools for Tailwind.
3. Install gems and JS dependencies:

   ```sh
   bundle install
   yarn install
   ```

4. Create and migrate the database:

   ```sh
   bin/rails db:prepare
   bin/rails db:seed
   ```

5. Start the development process manager (runs Rails, Tailwind, and JS bundlers):

   ```sh
   bin/dev
   ```

   Visit [http://localhost:3000](http://localhost:3000) once the server boots.

## 4. Sign in & sample data

- Seeds create TAMU-style sample accounts:
  - Admins: `health-admin{1,2,3}@tamu.edu`
  - Advisors: `rainsuds@tamu.edu`, `advisor.clark@tamu.edu`
  - Students: multiple `firstname.lastnameYY@tamu.edu`
- In development, Google OAuth uses test credentials defined in `config/environments/development.rb`. You can mock login without Google by creating `config/initializers/omniauth_test.rb` with:

  ```ruby
  if Rails.env.development?
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: SecureRandom.uuid,
      info: { email: "health-admin1@tamu.edu", name: "Health Admin One" }
    })
  end
  ```

  Afterwards hit `/users/auth/google_oauth2` and the mocked user will be provisioned.

- Enable the role switcher if you need to explore every dashboard: `ENABLE_ROLE_SWITCH=1 bin/rails server` (or add to `docker compose` overrides).

## 5. Developer toolbox

- Run Rails commands in Docker: `docker compose exec web bin/rails <command>`.
- Run Minitest suite: `docker compose exec web bin/rails test` or `ruby run_tests.rb -t controllers` (supports `-c` for coverage).
- Lint with RuboCop: `docker compose exec web bundle exec rubocop`.
- Tailwind builds are automatically handled by `css`/`bin/dev`; for manual runs use `bin/rails tailwindcss:build`.

## 6. Troubleshooting checklist

- **Database connection refused**: ensure Docker Desktop is running; on native setups verify PostgreSQL is listening on the port specified in `config/database.yml` (default user/password `dev_user`/`dev_pass`).
- **Google OAuth blocked**: check that `GOOGLE_OAUTH_CLIENT_ID`/`SECRET` exist and that the callback URL includes `/users/auth/google_oauth2/callback`.
- **PDF export errors**: WickedPdf is optional; if you see “WickedPdf not configured”, install wkhtmltopdf and add the gem/binaries or fall back to browser print-to-PDF.
- **Background jobs not delivering due reminders**: confirm `SurveyAssignmentNotifier.run_due_date_checks!` is scheduled (e.g., via cron/Heroku Scheduler) and that `JOB_CONCURRENCY` is sized correctly.
- **Role switcher hidden**: set `ENABLE_ROLE_SWITCH=1` or run in development/test.
- **Assets stale**: clear caches with `bin/rails log:clear tmp:clear` (or `docker compose exec web bin/rails ...`).

## 7. Next steps

- Review the [Development Guide](Development-Guide.md) for coding standards and workflow tips.
- Explore seeded dashboards to understand student/advisor/admin journeys.
- If deploying to Heroku, follow the [Heroku Guide](Heroku-Guide.md) and [Heroku Transfer](Heroku-Transfer.md) documents.
