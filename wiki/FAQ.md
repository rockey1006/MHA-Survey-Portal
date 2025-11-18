# FAQ

**Q: How do I reset the database?**  
A: `docker-compose exec web rails db:reset`

**Q: How do I run tests?**  
A: `docker-compose exec web rails test`

**Q: Where are environment variables set?**  
A: See [Local Environment Variables](Local-Environment-Variables.md) for instructions on using encrypted credentials, `.env`, and shell exports.

**Q: What is the backup and recovery process?**  
A: Review [Backup Plan](Backup-Plan.md) for policy details and [System Administration](System-Administration.md) for day-to-day procedures.

**Q: I lost my username or password—what should I do?**  
A: The app relies on TAMU Google SSO. Confirm you can log in at [Google Workspace](https://workspace.google.com/) with your TAMU account; if you’re locked out, contact the campus IT help desk. Once Google access is restored, return to the app and sign in with “Sign in with Google.”

**Q: How do we migrate data from the old platform?**  
A: Follow the extraction, transformation, and import workflow in [Data Migration](Data-Migration.md). Implement the suggested utilities before running imports in staging and production.

**Q: How do I add a new dependency?**  
A: Add to `Gemfile`, then rebuild with `docker-compose build`

**Q: How do I contribute?**  
A: See the [Contributing](Contributing.md) page

**Q: Who do I contact for help?**  
A: [List maintainers or contact info]
