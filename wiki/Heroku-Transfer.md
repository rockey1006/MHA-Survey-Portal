# Heroku — Transfer Admin / Ownership (with PostgreSQL backup via pg:backups)

Purpose
- This page documents how to transfer admin/owner privileges for a Heroku app (dashboard + CLI options), plus safe PostgreSQL backup/restore steps using Heroku's pg:backups. Use this when handing an app to another person or team.

---

## Quick contract
- Inputs: Heroku account with owner/admin rights for the app, Heroku CLI (optional), the recipient's Heroku account email.
- Outputs: App transferred (or collaborator added), verified access for new admin, and a current DB backup saved locally.
- Success criteria: New owner can manage the app; original owner has been removed (if desired); PostgreSQL backup exists and can be restored if needed.

## Prerequisites
1. You must be the app owner or have permission to transfer the app.
2. Recommended: Install Heroku CLI and be logged in:

```
heroku login
```

3. Know the recipient’s Heroku account email (or target team).
4. For DB operations: ensure the app uses Heroku Postgres and you have access to the app and database.
5. For screenshots: capture images at the points noted in the screenshots section and upload to the wiki.

## Important notes / safety
- Transferring ownership may move billing, add-on responsibility, and access to attached resources.
- Restoring a PG backup overwrites the target database. Schedule downtime or perform in maintenance window if necessary.
- Always take a pg:backups capture and download before a transfer or destructive actions.

## Table of contents
- Dashboard: Transfer ownership (UI)
- Dashboard: Add collaborator (if you don’t want to transfer)
- CLI: Transfer (optional)
- PostgreSQL: pg:backups (capture, list, download, restore)
- Verification & post-transfer cleanup
- Screenshots (placeholders)
- Troubleshooting & FAQ

## 1) Transfer ownership via Heroku Dashboard (recommended for most users)
1. Log in to https://dashboard.heroku.com and open the app you’re transferring.
2. In the app dashboard, open the "Settings" tab.
3. Scroll to the "Transfer app" or "Transfer ownership" section (usually near the bottom).
4. Click "Transfer" (or "Transfer ownership") and enter the recipient’s Heroku account email (or choose a team).
5. Confirm the transfer. Heroku will usually show a confirmation modal — read carefully and confirm.

**What to expect**
- The app’s owner will change to the recipient account (or team).
- Add-ons and billing may move or reassign depending on configuration.
- If anything looks unexpected, cancel and verify the recipient account and app access.

**When to use "Add collaborator" instead**
- If you want to give admin-like access but keep ownership (billing/transfer control) with the current account, add the user as a collaborator with admin permissions (see next section).

## 2) Add a collaborator (Dashboard)
1. In the app Dashboard, click "Access" (or open the "Settings" tab and find "Collaborators" / "Access").
2. Click "Add collaborator".
3. Enter the user’s email and choose the role (e.g., "Admin" if available; otherwise use default collaborator and explain required privileges).
4. Click "Add".

This keeps original owner as owner while giving administrative access to someone else.

## 3) Transfer / access via Heroku CLI (optional)
Note: Dashboard is safest for screenshots. CLI is useful for automation or when comfortable with commands.

- Transfer an app to another account (example):

```
heroku apps:transfer --app YOUR_APP_NAME --to new.owner@example.com
```

- If your CLI version doesn't support that exact flag syntax, run:

```
heroku help apps:transfer
```

to confirm flags for your installed CLI.

- Add a collaborator via CLI:

```
heroku access:add user@example.com --app YOUR_APP_NAME
```

- List collaborators:

```
heroku access --app YOUR_APP_NAME
```

Tip: If you need to assign the app to a team:

```
heroku apps:transfer --app YOUR_APP_NAME --to team:team-name
```

## 4) PostgreSQL: Safe backup with pg:backups (Heroku Postgres)

Before transferring ownership or performing destructive operations, take a backup.

### A. Capture a backup
- Create a new backup:

```
heroku pg:backups:capture --app YOUR_APP_NAME
```

This creates a backup (e.g., b001). You can check its status with:

```
heroku pg:backups --app YOUR_APP_NAME
```

or

```
heroku pg:backups:list --app YOUR_APP_NAME
```

### B. Download the latest or a specific backup
- Download the latest completed backup:

```
heroku pg:backups:download --app YOUR_APP_NAME
```

This will download a file like `latest.dump` into your current directory.

- Or download a specific backup id (example b001):

```
heroku pg:backups:download b001 --app YOUR_APP_NAME
```

### C. Inspect a backup (optional)
- Get info about a backup:

```
heroku pg:backups:info b001 --app YOUR_APP_NAME
```

### D. Restore a backup (CAUTION: this overwrites target DB)
- Restore a backup (for example restore b001 to your DATABASE_URL):

```
heroku pg:backups:restore b001 DATABASE_URL --app YOUR_APP_NAME
```

- Or restore from a downloaded public URL (or previously uploaded file):

```
heroku pg:backups:restore 'https://path.to/your/backup.dump' DATABASE_URL --app YOUR_APP_NAME
```

- If you need to restore into a different app/db, replace `--app` and `DATABASE_URL` appropriately (e.g., `HEROKU_POSTGRESQL_COLOR_URL`).

### E. Verify the database after restore
- Use psql to connect:

```
heroku pg:psql --app YOUR_APP_NAME
```

- Run a few sanity queries (counts, important tables).

### F. Automation / scheduling (optional)
- You can enable scheduled backups via Heroku Postgres plans or third-party tools; consult Heroku Postgres doc for retention/settings.

**Safety reminders**
- Restoring overwrites the target DB. Always confirm `DATABASE_URL` target and that you have a downloadable backup saved locally.
- Consider setting maintenance mode during big restores:

```
heroku maintenance:on --app YOUR_APP_NAME
```

then off:

```
heroku maintenance:off --app YOUR_APP_NAME
```

## 5) Verification & post-transfer cleanup
1. Verify the new owner can:
   - Open the app dashboard.
   - Modify settings, config vars, and collaborators.
   - View and manage add-ons and billing (if applicable).
2. Verify DB and add-ons are intact:
   - Run `heroku pg:backups` and `heroku addons` as the new owner.
3. If you want to remove the original owner:
   - If you transferred ownership, the original owner may be removed automatically; otherwise remove them from collaborators:

```
heroku access:remove old.user@example.com --app YOUR_APP_NAME
```

4. If the transfer involves moving to a team, ensure pipelines and CI integrations are reconfigured (if needed).

## 6) Troubleshooting & FAQ

**Q: The transfer button is missing — what now?**
- You might not have ownership rights. Only owners can transfer. Check your role under "Access". If using a team, only team admins can transfer apps to or from teams.

**Q: Billing or add-ons disappeared after transfer**
- Add-ons are tied to the app but billing account may change. Confirm add-on billing owner and check whether add-on attachments or plans require manual reassignment.

**Q: CLI command fails**
- Confirm you’re logged in (`heroku whoami`), confirm app name, and run `heroku help apps:transfer` to check syntax for your CLI version.

**Q: The other user doesn’t see the app after transfer**
- Confirm the recipient checked the email they use for Heroku and that the transfer completed. If transferring to a team, ensure the recipient is a team member.

## 7) Screenshots (placeholders)
- Upload screenshots to the Wiki or repository and use these filenames. Replace the image links in the Markdown after uploading.

1. App Settings (open app, Settings tab)
   - Filename: `images/01-heroku-app-settings.png`
   - Markdown: `![Heroku app Settings tab](images/01-heroku-app-settings.png)`
   - What to capture: full Settings page including "Transfer" section.
   - Alt text: Heroku app Settings showing Transfer section.

2. Transfer modal (enter recipient email)
   - Filename: `images/02-heroku-transfer-modal.png`
   - Markdown: `![Transfer modal](images/02-heroku-transfer-modal.png)`
   - What to capture: the Transfer confirmation modal with recipient email filled in.
   - Alt text: Transfer app confirmation modal.

3. Access / Add collaborator modal
   - Filename: `images/03-heroku-add-collaborator.png`
   - Markdown: `![Add collaborator](images/03-heroku-add-collaborator.png)`
   - What to capture: Add collaborator dialog showing email field and role selection.
   - Alt text: Add collaborator modal.

4. pg:backups capture result (CLI)
   - Filename: `images/04-pg-backups-capture.png`
   - Markdown: `![pg:backups capture CLI output](images/04-pg-backups-capture.png)`
   - What to capture: Terminal showing `heroku pg:backups:capture` output and resulting backup ID.
   - Alt text: Terminal output showing pg:backups capture.

5. pg:backups list / download
   - Filename: `images/05-pg-backups-list.png`
   - Markdown: `![pg:backups list](images/05-pg-backups-list.png)`
   - What to capture: Terminal output of `heroku pg:backups` and `heroku pg:backups:download` success.

## 8) Checklist (before you finalize transfer)
- [ ] Take a current pg:backups capture and download it.
- [ ] Verify recipient’s Heroku account email and team membership.
- [ ] Inform recipient of any CI/billing steps they must complete.
- [ ] Optionally add recipient as collaborator and test access before transfer.
- [ ] Document any custom maintenance steps (DNS, pipelines, external services).

## 9) Minimal change log / record
- Record the transfer in your team notes: who transferred, date/time, app name, backup id (e.g., b001), and backup filename (e.g., my-app-latest.dump).

**Example log entry:**
- 2025-10-31 — Transferred `my-app` to new.owner@example.com. Backup `b004` captured and downloaded as `my-app-2025-10-31.dump`.

## 10) Further reading / links
- Heroku Dashboard docs: https://devcenter.heroku.com/categories/dashboard
- Heroku CLI docs: https://devcenter.heroku.com/articles/heroku-cli
- Heroku Postgres & pg:backups: https://devcenter.heroku.com/articles/heroku-postgres-backups

---

*File created: HEROKU_ADMIN_TRANSFER.md*
