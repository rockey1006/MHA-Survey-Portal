# System Administration

Guidance for day-to-day maintenance of the Health application, including data backups and recovery procedures. Use this alongside the [Heroku Guide](Heroku-Guide.md) and [Local Environment Variables](Local-Environment-Variables.md) when operating the platform.

## Backup plan

For detailed schedules, storage destinations, and restore drills, see the dedicated [Backup Plan](Backup-Plan.md).

### Production (Heroku)

- **Primary database**: Heroku Postgres Standard-0 (or comparable) instance.
- **Frequency**: Schedule an automated backup daily at 02:00 UTC via `heroku pg:backups schedule`.
- **Retention**: Keep at least the last 7 daily snapshots and 4 weekly snapshots.
- **Manual backups**: Before major deployments or migrations, trigger `heroku pg:backups:capture`.
- **Artifacts**: Store downloaded backups (`.dump` files) in an encrypted S3 bucket or campus-managed storage with access logging.

### Staging / QA

- Trigger weekly backups or prior to disruptive testing using the same Heroku CLI commands.
- Optionally mirror production schedule if staging hosts irreplaceable data.

### Local development

- Use the provided seeds; routine backups are optional.
- For ad-hoc snapshots, run:

  ```sh
  docker compose exec db pg_dump -U dev_user -F c health_development > backups/health-dev-$(date +%Y%m%d).dump
  ```

  Ensure the `backups/` directory is ignored by Git.

## Recovery procedures

### Production outage

1. **Assess scope**: Check Heroku status and application logs (`heroku logs --tail`).
2. **Scale resources**: Confirm dynos and the database are running; restart with `heroku ps:restart --app <app-name>` if needed.
3. **Data restore**: If corruption or data loss occurred:
   - List available backups: `heroku pg:backups --app <app-name>`.
   - Promote the desired backup: `heroku pg:backups:restore <backup-id> DATABASE_URL --app <app-name> --confirm <app-name>`.
   - Monitor progress; expect the app to be unavailable during restore.
4. **Post-restore tasks**:
   - Run `heroku run rails db:migrate` if schema changes are pending.
   - Re-enqueue reminders with `SurveyAssignmentNotifier.run_due_date_checks!` (via Rails console) to resume notifications.
   - Validate dashboards, survey access, and exports manually.

### Staging/local recovery

- Restore dumps using:

  ```sh
  pg_restore --clean --no-owner -d health_development backups/health-dev-YYYYMMDD.dump
  ```

- Re-run `bin/rails solid_queue:start` or relevant background jobs if they were stopped.

## Verification & monitoring

- After every backup or restore, confirm you can sign in, view dashboards, and generate reports.
- Track uptime via Heroku Metrics or your preferred APM provider.
- Enable alerts for failed Scheduled Jobs (e.g., `SurveyNotificationJob`) so administrators can re-run them promptly.

## Documentation updates

- Record the current backup schedule and storage locations in `doc/operations.md` or your team runbook.
- Review this page quarterly to reflect infrastructure or tooling changes.
