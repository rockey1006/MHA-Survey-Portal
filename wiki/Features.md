# Features

The Health application ships with a large set of features that are reflected in the codebase today. The sections below summarise the current capabilities and reference the areas of the repository that implement them so you can trace behaviour quickly.

## Authentication & Access Control

- **Single sign-on** via Google OAuth 2 (`OmniauthCallbacksController` + Devise) with TAMU e-mail enforcement.
- **Role-aware dashboards**: students, advisors, and admins are redirected to dedicated experiences (`DashboardsController`).
- **Environment-controlled role switcher** to preview other dashboards in development/test or when `ENABLE_ROLE_SWITCH=1` (`dashboards#switch_role`, `app/views/shared/_role_switcher.html.erb`).
- **Profile gating** that forces incomplete student profiles through the onboarding flow before accessing the app (`ApplicationController#check_student_profile_complete`).

## Student Experience

- **Dashboard overview** of assigned surveys, completion status, and quick actions (`dashboards#student`).
- **Secure survey access** with signed download tokens for response PDFs and composite reports (`SurveyResponsesController`, `SurveyResponse.build`).
- **Self-service profile management** for program metadata, contact information, and accessibility preferences (`StudentProfilesController`, `SettingsController`).

## Advisor Experience

- **Advisee roster management** with key stats and quick links to student records (`dashboards#advisor`).
- **Survey assignment workflows** that populate `StudentQuestion` records and create `SurveyAssignment`s, including bulk “assign all” actions (`Advisors::SurveysController`).
- **Unassign and notification flows** that clean up responses and alert students when surveys change (`Advisors::SurveysController#unassign`, `Notification`).
- **Feedback capture tools** tied to surveys and competencies (`FeedbacksController`, `Feedback` model).

## Administrator Tooling

- **Survey builder** with nested categories, questions, and track assignments (`Admin::SurveysController`, `Survey`, `Category`, `Question`).
- **Lifecycle controls** for activating, archiving, previewing, and deleting surveys, each logged for auditing (`SurveyChangeLog`, `SurveyAuditLog`).
- **Role & membership management** (`dashboards#manage_members`, `#update_roles`) plus advisor/student bulk assignments (`#manage_students`, `#update_student_advisors`).
- **System overview dashboard** with program-wide counts and recent administrator activity (`dashboards#admin`).

## Surveys, Feedback & Evidence

- **Track-aware survey distribution** using `SurveyTrackAssignment` to target Residential vs Executive cohorts.
- **Automatic assignment hooks** (`SessionsController#after_sign_in_path_for`, `SurveyAssignments::AutoAssigner` hook point) ensuring students receive the correct surveys on sign-in.
- **Response capture** across multiple question types, evidence URLs, and advisor evaluations (`StudentQuestion`, `QuestionResponse`).
- **Evidence link validation** to confirm Google Drive/Docs permissions before submission (`EvidenceController#check_access`).
- **Advisor & student feedback loops** stored per category with historical context (`Feedback`, `CompositeReportGenerator#feedbacks_by_category`).

## Analytics & Reporting

- **Interactive analytics hub** backed by `Reports::DataAggregator`, surfaced via a React + Chart.js interface (`app/javascript/reports/app.js`, `reports_controller`).
- **Filterable insights** for tracks, semesters, advisors, surveys, competencies, and students (`Api::ReportsController`).
- **Export pipelines** for PDF (WickedPdf) and Excel (`ReportsController#export_pdf`, `Reports::ExcelExporter`) with section-aware exports.
- **Student records matrix** summarising completion progress, advisor relationships, and feedback timelines (`StudentRecordsController#index`).
- **Composite assessment PDFs** combining survey answers, feedback, and evidence with caching (`CompositeReportGenerator`, `CompositeReportCache`).

## Notifications & Automation

- **In-app notification centre** with unread counters, list views, and batch mark-as-read (`NotificationsController`, `Notification` model).
- **Event-driven messaging** for assignment, due soon, overdue, completion, survey updates, and archive events (`SurveyNotificationJob`, `SurveyAssignmentNotifier`).
- **User preferences** for notification delivery and text scaling persisted in the `users` table (`SettingsController`).

## Accessibility & Personalisation

- **High-contrast mode** toggle with persistent preferences (`app/javascript/application.js`, `app/assets/stylesheets/application.css`).
- **User-controlled font scaling** via `text_scale_percent` applied at the `<html>` root (`layouts/application.html.erb`, `SettingsController`).
- **Modern browser enforcement** to guarantee support for CSS features used throughout the UI (`ApplicationController#allow_browser`).

## API & Integrations

- **Reports JSON API** powering the analytics SPA (`/api/reports/*` routes, `Api::ReportsController`).
- **Evidence checker endpoint** for validating external artefacts (`/evidence/check_access`).
- **Health check** exposed at `/up` for monitoring (`config/routes.rb`).

## Data Integrity & Auditing

- **Audit trails** for survey changes (`SurveyChangeLog`, `SurveyAuditLog`) and admin previews.
- **Deduplicated notifications** using scoped uniqueness on `Notification` records.
- **Signed tokens** securing survey response downloads (`SurveyResponse#signed_download_token`).

## Tooling & Operations

- **Docker Compose stack** for local development with separate `web`, `css`, and `db` services (`docker-compose.yml`).
- **Seed data generator** that provisions admin/advisor/student personas, surveys, and synthetic responses (`db/seeds.rb`).
- **Unified test runner** (`run_tests.rb`) wrapping `rails test` with optional coverage and suite selection.
- **Heroku deployment guides** covering ownership transfer and day-to-day platform operations (see `Heroku-Guide.md`, `Heroku-Transfer.md`).

## Planned & Future Enhancements

- **Email delivery**: UI toggles exist, but mailers beyond Devise defaults have not been wired to notification events.
- **Automatic track assignment service**: controllers invoke `SurveyAssignments::AutoAssigner`; ensure the service is present and configured for your deployment.
- **Additional accessibility presets** such as dyslexia-friendly fonts and reduced motion modes (placeholders noted in stylesheets).
