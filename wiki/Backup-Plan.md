# Backup Plan

This document outlines what data must be backed up, how often backups run, where artifacts are stored, and how to verify restores for the Health application.

## Objectives

- Protect production data (users, survey responses, feedback, notifications) against loss or corruption.
- Provide auditable retention windows for compliance with TAMU policies.
- Enable rapid recovery during outages or misconfigured deployments.

## Scope of backups

| Asset | Location | Notes |
| --- | --- | --- |
| PostgreSQL database | Heroku Postgres | Primary system of record; includes roles, survey data, metrics |
| Uploaded files | Active Storage local/S3 (depending on environment) | If S3 is used, rely on bucket-level versioning; otherwise archive `/storage/` |
| Application configuration | `config/credentials.yml.enc`, `.env` files | Store copies in secure vaults/password managers |
| Infrastructure configs | `docker-compose.yml`, `Procfile`, scripts | Version-controlled in Git; tag releases before major deployments |

## Backup schedule

### Production (Heroku)

- **Daily automated snapshot**: `heroku pg:backups schedule DATABASE_URL --at '02:00 UTC'`
- **Weekly full export**: Download Monday’s snapshot to encrypted storage (`heroku pg:backups:download`)
- **Before major releases**: Run `heroku pg:backups:capture --app <app-name>`
- **Retention policy**: Keep 7 daily, 4 weekly, and 3 monthly snapshots; purge older dumps quarterly
- **Responsible role**: Primary on-call administrator (rotating), documented in runbook

### Staging / QA

- **Weekly snapshot**: `heroku pg:backups:capture --app <staging-app>`
- **Retention**: Keep last 4 snapshots to reproduce test data if needed
- **Optional**: Mirror production daily schedule if staging stores critical pilot data

### Local development

- **Ad-hoc**: Developers may dump local data when reproducing issues

  ```sh
  docker compose exec db pg_dump -U dev_user -F c health_development > backups/health-dev-$(date +%Y%m%d).dump
  ```

- Ensure `backups/` is ignored by Git and stored securely when containing real user data

## Storage destinations

- **Encrypted S3 bucket** (recommended) with limited IAM access and object versioning
- **On-premises secure file share** managed by TAMU IT, if cloud storage is restricted
- Track download locations and access logs for auditability

## Verification & testing

- **Monthly restore test**: Use staging to restore the most recent production snapshot and run smoke tests (sign in, load dashboards, generate reports)
- **Checksum verification**: After download, run `shasum` or equivalent to record integrity hashes
- **Alerting**: Enable notifications for failed Heroku backups via add-ons (e.g., PGBackups to Slack/email)

## Recovery checklist

1. Declare incident and notify stakeholders (product owner, advisors if impacted).
2. Stop writes (scale web dynos to zero or enable maintenance mode).
3. Identify the latest usable backup (`heroku pg:backups --app <app-name>`).
4. Restore snapshot:

   ```sh
   heroku pg:backups:restore b123 DATABASE_URL --app <app-name> --confirm <app-name>
   ```

5. Monitor restore status (`heroku pg:backups:info b123`).
6. Run post-restore migrations: `heroku run rails db:migrate --app <app-name>`.
7. Validate functionality (sign-in, survey workflows, reporting exports).
8. Re-enable web dynos and communicate resolution.
9. Log the incident and lessons learned in the operations runbook.

## Documentation & ownership

- Maintain current on-call contacts and access credentials in `doc/operations.md` (private repository).
- Review this plan twice per semester to adjust for infrastructure changes or policy updates.
- Cross-reference with [System Administration](System-Administration.md) for broader maintenance procedures.
