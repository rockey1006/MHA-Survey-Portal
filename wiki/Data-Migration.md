# Data Migration

This guide documents how to move student, advisor, and survey data from legacy systems into the Health application. It focuses on planning, conversion utilities, validation, and transfer workflows.

## Source systems

Identify each legacy source and the format it exposes:

| Source | Export Format | Notes |
| --- | --- | --- |
| Legacy advising app | CSV export (students, advisors, survey results) | Accessible via nightly report or manual export |
| Offline survey spreadsheets | XLSX | Structured with question columns matching `Survey#survey_id` |
| Historical notifications | None | Optional; can be regenerated after import |

Document credentials, data owners, and any rate limits in the team runbook.

## Target schema overview

- `users`: keyed by `email`, includes `role`, `first_name`, `last_name`
- `student_profiles`: linked to users with `uin`, `classification`, `major`
- `surveys`, `competencies`, `questions`: defined by seeds (`db/seeds.rb`) and YAML fixtures (`db/data/program_surveys.yml`)
- `survey_responses` and `question_responses`: store student submissions
- `feedbacks`: capture advisor/student qualitative feedback

Refer to [Code Documentation](Code-Documentation.md) for detailed model relationships.

## Conversion workflow

1. **Extract** legacy data into CSV/JSON files stored in `tmp/imports/` (ignored by Git).
2. **Transform** the files to match Rails models:
   - Normalize email casing
   - Map legacy roles to `admin`, `advisor`, `student`
   - Align survey question identifiers with `questions.question_order`
   - Convert timestamps to UTC ISO 8601 format
3. **Load** via Rails tasks or scripts.

### Suggested utilities

Create import scripts under `lib/tasks/` or `scripts/`:

- `lib/tasks/import_users.rake`: Reads `tmp/imports/users.csv`, upserts `User` and `StudentProfile` records.
- `lib/tasks/import_survey_responses.rake`: Maps legacy survey answers to `SurveyResponse` + `QuestionResponse` entries.
- `scripts/migrate_from_legacy.rb`: Ruby script that orchestrates the tasks and logs progress.

Pseudo-code structure for an import task:

```ruby
namespace :import do
  desc "Load users from tmp/imports/users.csv"
  task users: :environment do
    require "csv"
    path = Rails.root.join("tmp", "imports", "users.csv")
    CSV.foreach(path, headers: true) do |row|
      user = User.find_or_initialize_by(email: row["Email"].strip.downcase)
      user.assign_attributes(
        first_name: row["First Name"],
        last_name: row["Last Name"],
        role: row["Role"].presence || "student"
      )
      user.save!

      if user.student?
        profile = user.student_profile || user.build_student_profile
        profile.update!(uin: row["UIN"], classification: row["Classification"], major: row["Major"])
      end
    end
  end
end
```

Store final utilities in version control and add specs to cover edge cases.

## Validation checklist

- Run imports in the **staging** environment first.
- After loading data, verify:
  - Counts of users/surveys match source totals.
  - Sample students can sign in and view historical responses.
  - Reports generated via `ReportsController` reflect imported data.
- Use `rails test test/models/*_test.rb` to ensure core models remain valid.
- Take a fresh backup before and after large imports (see [Backup Plan](Backup-Plan.md)).

## Transfer schedule

- Plan migrations during low-traffic windows (e.g., evenings, weekends).
- Communicate downtime expectations to advisors and students.
- For phased migrations, toggle legacy system to read-only during the cutover to avoid divergence.

## Rollback strategy

- Capture a database snapshot immediately before running import tasks.
- If the import fails, restore from the snapshot (`heroku pg:backups:restore`).
- Track imported record IDs to allow targeted deletion if partial cleanup is needed.

## Next steps

- Implement the suggested utilities and check them into `lib/tasks/`.
- Document command usage in `README.md` or `wiki/Development-Guide.md`.
- Add automated tests for transformation helpers and import tasks.
- Schedule end-to-end rehearsals before the production cutover.
