# Heroku Guide

This page provides instructions for navigating Heroku, managing environment variables, switching user roles, and using the Heroku CLI for the Health project.

---

## Navigating Heroku Dashboard

1. Go to [Heroku Dashboard](https://dashboard.heroku.com/).
2. Select the Health project app from your list.
3. Use the tabs (Overview, Resources, Deploy, Metrics, Activity, Access, Settings) to manage your app.

---

## Managing Environment Variables

1. In the Heroku Dashboard, go to your app.
2. Click on the **Settings** tab.
3. Reveal Config Vars to view or edit environment variables.
4. Add, edit, or delete variables as needed (e.g., `RAILS_MASTER_KEY`, `DATABASE_URL`, custom flags).

---

## Changing Role Access Flag (Quick Role Switch)

- Some roles (admin, advisor, student) may be controlled by a flag in the database or as an environment variable.
- To quickly switch a role flag (e.g., from 1 to 0):
  1. Open the Heroku Dashboard > Resources > click "Run Console" (or use Heroku CLI, see below).
  2. Run a Rails console command, e.g.:
     ```ruby
     User.find_by(email: 'user@example.com').update(role_flag: 1) # or 0
     ```
  3. Alternatively, update the flag via environment variable in Config Vars if your app uses ENV for roles.

---

## Using the Heroku CLI

### Installation
- [Install Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)

### Common Commands

- **Login:**
  ```sh
  heroku login
  ```
- **List apps:**
  ```sh
  heroku apps
  ```
- **Open app dashboard:**
  ```sh
  heroku open -a <app-name>
  ```
- **Run Rails console:**
  ```sh
  heroku run rails console -a <app-name>
  ```
- **View logs:**
  ```sh
  heroku logs --tail -a <app-name>
  ```
- **Set config var:**
  ```sh
  heroku config:set VAR_NAME=value -a <app-name>
  ```
- **Get config vars:**
  ```sh
  heroku config -a <app-name>
  ```

---

## Tips
- Always be careful when changing environment variables or role flags in production.
- Use the CLI for advanced management and scripting.
- For more, see the [Heroku CLI documentation](https://devcenter.heroku.com/articles/heroku-cli-commands).
