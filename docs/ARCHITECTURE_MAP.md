# Architecture Map

## High-level structure

The app is a Rails application with role-aware dashboards and a few service-heavy domains.

Main layers:

- controllers: request handling and page actions
- models: persistence and associations
- services: reporting, grade imports, and workflow logic
- views: ERB-based UI with shared `c-` CSS component classes

## Main domains

### Authentication and roles

Core role handling is built around `User` plus role-specific profiles such as:

- `Student`
- `Advisor`
- admin users through `User#role`

Dashboards route users into the right workflow area.

### Surveys

Important models:

- `Survey`
- `Category`
- `Question`
- `SurveyAssignment`
- `SurveyResponse`
- `StudentQuestion`
- `Feedback`

Purpose:

- define competency surveys
- assign them to students
- collect self-ratings and other answers
- allow advisor review and feedback

### Reporting

Important code:

- `app/services/reports/data_aggregator.rb`
- `app/controllers/reports_controller.rb`
- `app/views/reports/`
- `app/views/composite_reports/`

Purpose:

- aggregate survey and advisor data
- expose program-level reports
- generate student composite reports

### Grade imports

Important models:

- `GradeImportBatch`
- `GradeImportFile`
- `GradeCompetencyEvidence`
- `GradeCompetencyRating`
- `GradeImportPendingRow`

Important services:

- `app/services/grade_imports/batch_processor.rb`
- `app/services/grade_imports/batch_rating_rebuilder.rb`
- `app/services/grade_imports/pending_row_reconciler.rb`
- `app/services/grade_imports/derived_scorebook.rb`

Purpose:

- ingest faculty file uploads
- create competency evidence
- derive student competency ratings from imported course evidence
- preserve pending unmatched rows for later reconciliation

### Admin competency matrix

Important code:

- `app/controllers/admin/competencies_controller.rb`
- `app/services/admin/competency_matrix.rb`
- `app/views/admin/competencies/index.html.erb`

Purpose:

- show self, advisor, and course ratings side by side
- filter by student and competency context

### Program configuration

Important code:

- `app/controllers/admin/program_setups_controller.rb`
- `app/controllers/admin/target_levels_controller.rb`
- `app/views/admin/program_setups/`

Purpose:

- manage tracks, majors, cohorts, semesters
- manage competency target levels

### People management

Important code:

- `app/controllers/dashboards_controller.rb`
- `app/views/dashboards/people_management.html.erb`
- `app/views/dashboards/_people_members_tab.html.erb`
- `app/views/dashboards/_people_students_tab.html.erb`

Purpose:

- manage role assignments
- manage student track / group / advisor assignments

## Data flow for competency ratings

### Self ratings

Source:

- student survey responses

Primary data path:

- `StudentQuestion`

### Advisor ratings

Source:

- advisor feedback

Primary data path:

- `Feedback`

### Course ratings

Source:

- grade import batches

Primary data path:

- `GradeCompetencyEvidence`
- `GradeCompetencyRating`

## Important design decisions

### Advisor and course ratings are separate

Imported course ratings should not overwrite advisor feedback.

They are intentionally shown as separate sources in:

- admin competencies view
- student records
- reports where applicable

### Evidence rows are preserved

The app does not collapse raw import evidence away. Derived ratings are built from evidence rows so provenance can be shown later.

### Duplicate protection is intentional

Repeated uploads of the same source data should not generate duplicated evidence or duplicated pending rows.

### Pending unmatched rows are intentional

When a student does not yet exist locally, import rows are staged instead of discarded. They can be reconciled later when the student record exists.

## Files to understand first

- [app/services/grade_imports/batch_processor.rb](/home/rainsuds/codespace/MHA-Survey-Portal/app/services/grade_imports/batch_processor.rb)
- [app/services/admin/competency_matrix.rb](/home/rainsuds/codespace/MHA-Survey-Portal/app/services/admin/competency_matrix.rb)
- [app/services/reports/data_aggregator.rb](/home/rainsuds/codespace/MHA-Survey-Portal/app/services/reports/data_aggregator.rb)
- [app/controllers/admin/grade_import_batches_controller.rb](/home/rainsuds/codespace/MHA-Survey-Portal/app/controllers/admin/grade_import_batches_controller.rb)
- [app/views/admin/program_setups/show.html.erb](/home/rainsuds/codespace/MHA-Survey-Portal/app/views/admin/program_setups/show.html.erb)
- [app/views/dashboards/people_management.html.erb](/home/rainsuds/codespace/MHA-Survey-Portal/app/views/dashboards/people_management.html.erb)
