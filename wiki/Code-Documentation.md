# Code Documentation

This page links the major areas of the Rails codebase to the functionality described in the wiki. Use it as a map when you are exploring or making changes.

## Controllers

### Application-wide

- `application_controller.rb` – Authenticates users, enforces modern browser support, preloads notifications, and redirects incomplete student profiles to onboarding.
- `sessions_controller.rb` – Custom Devise session flow that triggers survey auto-assignment after login and protects against GET sign-out calls.
- `omniauth_callbacks_controller.rb` – Handles Google OAuth callbacks, restricts logins to TAMU domains, and routes users to their role dashboards.
- `dashboards_controller.rb` – Entry point for all role dashboards plus admin/advisor management tables and the environment-controlled role switcher.
- `accounts_controller.rb` – Allows users to update their display name.
- `settings_controller.rb` – Persists per-user accessibility preferences such as text scaling and notification settings.
- `notifications_controller.rb` – Lists, shows, and marks notifications as read; supports bulk mark-all-read.
- `student_profiles_controller.rb` – CRUD interface for completing and updating student profile details.
- `student_records_controller.rb` – Builds the survey completion matrix used by advisors/admins.
- `surveys_controller.rb` – Student-facing survey submission and autosave endpoints.
- `survey_responses_controller.rb` – Renders individual survey responses, secure downloads, and composite assessment PDFs.
- `question_responses_controller.rb`, `feedbacks_controller.rb`, `questions_controller.rb`, `categories_controller.rb`, `evidence_controller.rb`, `pages_controller.rb` – Supporting CRUD and utility endpoints used across the app.

### Namespaced controllers

- `admin/base_controller.rb` – Ensures only admins access the namespace.
- `admin/surveys_controller.rb` – Survey builder, lifecycle management, and change logging.
- `admin/questions_controller.rb` – Global question management helpers.
- `admin/survey_change_logs_controller.rb` – Exposes survey audit history.
- `advisors/base_controller.rb` – Guards advisor-only flows while permitting admin oversight.
- `advisors/surveys_controller.rb` – Track-aware assignment/unassignment tools and due-date management.
- `advisors/students_controller.rb` – Advisor-specific student details and updates.
- `api/reports_controller.rb` – JSON API powering the analytics dashboard (filters, benchmark, competency, course, alignment endpoints).
- `accounts_controller.rb`, `settings_controller.rb`, and Devise controllers support all namespaces.

## Models

- `User` – Core devise record with Google OAuth, role enum, profile associations, and text scaling preference.
- `Student`, `Advisor`, `Admin` – Profile tables keyed by `*_id`, linked back to `User` and used for authorisation scopes.
- `Survey`, `Category`, `Question`, `SurveyQuestion` – Survey structure including track assignments (`SurveyTrackAssignment`) and nested categories/questions.
- `SurveyAssignment` – Connects surveys to students/advisors with due dates, completion tracking, and notification hooks.
- `SurveyResponse`, `QuestionResponse`, `StudentQuestion` – Response materialisation and analytics helpers including signed download tokens.
- `Feedback` – Advisor feedback per survey/category with optional scoring.
- `Notification` – Polymorphic in-app notification records with deduplication.
- `SurveyChangeLog`, `SurveyAuditLog` – Audit history for admin actions.
- `CategoryQuestion`, `SurveyCategoryTag`, `SurveyTrackAssignment`, `SurveyAssignment` – Join models supporting survey metadata.
- `Category` and `Question` expose enums for question types and required logic used throughout controllers and views.

## Services & Modules

- `Reports::DataAggregator` – Central analytics service calculating filters, benchmarks, competency summaries, course outcomes, and alignment data based on the current user’s scope.
- `Reports::ExcelExporter` – Builds XLSX dashboards from aggregator payloads using Axlsx.
- `CompositeReportGenerator` – Produces cached composite assessment PDFs by merging student answers and advisor feedback (requires WickedPdf).
- `CompositeReportCache` – Lightweight cache wrapper keyed by survey response fingerprint.
- `SurveyAssignmentNotifier` – Utility for scheduling “due soon” and “past due” notifications and sending ad-hoc alerts.
- `SurveyAssignments::AutoAssigner` (expected under `app/services/survey_assignments/`) – Hook invoked on login/OAuth to assign track-appropriate surveys; ensure this service exists and is configured.

## Background Jobs & Tasks

- `SurveyNotificationJob` – Processes notification events (`:assigned`, `:due_soon`, `:past_due`, `:completed`, `:survey_updated`, `:survey_archived`, `:custom`).
- `ApplicationJob` – Base job inheriting from ActiveJob; queue configuration in `config/queue.yml` (polling dispatcher with configurable concurrency).
- Rake tasks under `lib/tasks` (`notifications.rake`, `add_questions.rake`) provide maintenance utilities.
- The `scripts/coverage_report.rb` helper converts SimpleCov output into CI-friendly summaries.

## Frontend Structure

- Stimulus controllers in `app/javascript/controllers/` (`reports_controller.js`, `filters_panel_controller.js`, `survey_bulk_controller.js`) attach behaviour to Rails views.
- React analytics app in `app/javascript/reports/app.js` renders the advisor/admin dashboard using Chart.js 4; mounted via `ReportsController` view `reports/show.html.erb`.
- High-contrast and accessibility helpers reside in `app/javascript/application.js` alongside Turbo initialisation.
- Tailwind CSS builds are managed through `bin/rails tailwindcss:*` commands triggered in Docker (`css` service) or via `bin/dev` locally.

## Views & Layouts

- `app/views/layouts/application.html.erb` – Primary layout with role-aware navigation, notification badge, and text-scaling CSS variables.
- `app/views/layouts/auth.html.erb` – Minimal layout for Devise views.
- `app/views/layouts/mailers/*.erb` – Base ActionMailer templates (Devise defaults).
- Partial directories (`app/views/shared`, `app/views/reports`, etc.) group reusable UI fragments like navbars, role switcher, and notification dropdowns.

## API Endpoints

- `/api/reports/filters` – Filter metadata for the analytics app.
- `/api/reports/benchmark` – Cohort benchmark statistics.
- `/api/reports/competency-summary`, `/course-summary`, `/alignment` – Data for charts and tables rendered in React.
- `/evidence/check_access` – JSON endpoint to validate Google Drive URLs.
- `/up` – Rails health check consumed by uptime monitors.

## Database Schema Highlights

- PostgreSQL primary store with UUID/sequence ids depending on table (see `db/schema.rb`).
- `users` table keyed by `id` with enum `role`, OAuth fields (`uid`, `avatar_url`), notification & text-scaling preferences.
- `students`, `advisors`, `admins` tables reuse `*_id` primary keys that match the corresponding `users.id` for tight coupling.
- Surveys reference categories/questions via `survey_id` and `category_id`; responses link through `student_questions` and `question_responses`.
- Notifications, assignments, change logs, and audit logs include indexed timestamps for efficient dashboard queries.

## Supporting Artifacts

- Sample data: `db/seeds.rb` populates surveys, assignments, notifications, and synthetic responses across cohorts.
- Tests: `test/` directory follows Minitest conventions (`test_helper.rb` enables optional SimpleCov via `COVERAGE=1`).
- Tooling: `run_tests.rb` (Ruby script) wraps `rails test`; `docker-compose.yml` defines local containers; `Procfile.dev` and `bin/dev` orchestrate foreman-style processes.

Refer back to the repository for deeper dives—each class and module is documented inline with concise comments to speed up comprehension.
