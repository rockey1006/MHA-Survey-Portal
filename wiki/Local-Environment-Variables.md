# Local Environment Variables

This guide explains how the Health project manages configuration secrets and environment variables during development. Use it alongside the [Getting Started](Getting-Started.md) and [Google OAuth Setup](Google-OAuth-Setup.md) guides.

## Configuration layers

The application reads configuration data from several sources, in this order of precedence:

1. **Process environment** – values exported in your shell, Docker Compose, or system settings.
2. **Encrypted credentials** – values stored in `config/credentials.yml.enc` surfaced via `Rails.application.credentials`.
3. **Fallback defaults** – values hard-coded for development (e.g., Google OAuth defaults in `config/environments/development.rb`).

## Using encrypted credentials (recommended)

1. Ensure you have the `config/master.key` file (request it from the team if missing).
2. Run `bin/rails credentials:edit`. Rails opens the decrypted YAML in your editor.
3. Add secrets under relevant namespaces, for example:

   ```yaml
   google_oauth:
     client_id: YOUR_CLIENT_ID
     client_secret: YOUR_CLIENT_SECRET
   mailer:
     from: health-support@tamu.edu
   solid_queue:
     redis_url: redis://localhost:6379/0
   ```

4. Save and exit; Rails re-encrypts the file automatically.
5. Access values in code via `Rails.application.credentials.dig(:google_oauth, :client_id)` or expose them to ENV in an initializer:

   ```ruby
   creds = Rails.application.credentials
   ENV["GOOGLE_OAUTH_CLIENT_ID"] ||= creds.dig(:google_oauth, :client_id)
   ENV["GOOGLE_OAUTH_CLIENT_SECRET"] ||= creds.dig(:google_oauth, :client_secret)
   ```

Keep `config/master.key` out of version control but share it securely with trusted teammates.

## Using a local `.env` file (optional)

The project does not ship with a Dotenv gem, but Docker Compose and most shells can read key-value files. Place a `.env` file in the project root with entries like:

```env
GOOGLE_OAUTH_CLIENT_ID=...
GOOGLE_OAUTH_CLIENT_SECRET=...
ENABLE_ROLE_SWITCH=1
JOB_CONCURRENCY=5
SOLID_QUEUE_REDIS_URL=redis://redis:6379/0
```

- Docker Compose automatically reads `./.env` and injects values into services (see `docker-compose.yml`).
- For `bin/dev`, load the file manually: `export $(cat .env | xargs) && bin/dev` (macOS/Linux) or `Get-Content .env | ForEach-Object { $name, $value = $_ -split '='; [System.Environment]::SetEnvironmentVariable($name, $value) }` on PowerShell.

## Per-machine secrets

- Avoid committing `.env` files; add them to `.gitignore`.
- Store long-lived credentials (API keys, database passwords) in your password manager and rotate them periodically.
- For Windows, use `setx VAR VALUE` to persist variables, or the System Properties UI under *Environment Variables*.

## Docker Compose configuration

- The `web` and `css` services inherit variables from `.env` and from `docker-compose.yml` `environment` blocks.
- If you change secrets, run `docker compose down` to stop containers, then `docker compose up --build` to ensure the new values are loaded.
- Database credentials for development (`dev_user` / `dev_pass`) are defined in `config/database.yml`; override them by setting `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` before the first boot.

## Inspecting environment values

- Rails console: `docker compose exec web bin/rails runner 'puts ENV["GOOGLE_OAUTH_CLIENT_ID"]'`
- Application config: `docker compose exec web bin/rails credentials:show`
- Docker containers: `docker compose exec web env | grep GOOGLE`

## Committing safe defaults

Some development defaults (like the sample Google OAuth client) live in `config/environments/development.rb` so new contributors can sign in immediately. Replace them with organization-specific credentials for production or staging environments to avoid exceeding shared quotas.
