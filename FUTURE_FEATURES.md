# FUTURE FEATURES & ROADMAP

This document captures proposed features, high-level specs, prioritization, and an implementation checklist for future work on the Health Professions application.

Use this file as the canonical place to propose work, provide the minimum information developers/designers need to estimate and implement, and record implementation notes and milestones.

---

## How to propose a feature

When creating a new feature proposal, add a new section below using the template. Keep proposals concise but include enough detail to evaluate effort and dependencies.

Feature proposal template
- Title: short descriptive name
- Author / Date:
- Summary: one-paragraph description of what the feature will do and why
- Motivation: who benefits and what problem it solves
- User stories (3–6): short "As a <role>, I want <goal>, so that <benefit>" statements
- Acceptance criteria: precise, testable bullets (what counts as done)
- Data model / schema changes: list of migrations, new models, FK constraints
- API / endpoints / controller changes: public endpoints and expected params
- UI / interaction notes: key screens or components, behavior details
- Security / permissions: roles allowed and guardrails
- Tests required: unit, controller, integration, system tests to add
- Rollout / migration notes: seeding, data migration, destructive operations
- Dependencies: other features, gems, infra (e.g., Active Storage, Pundit)
- Rough estimate: sizing (S/M/L/XL) and preferred sprint
- Implementation checklist: actionable tasks to complete the feature

---

## Prioritization guidance

Use the following quick-priority categories when assigning a priority to a proposal:

- P0 — Critical: Must have before next release (security, blocking bugfixes)
- P1 — High: Major features for the next milestone (user-visible, high impact)
- P2 — Medium: Valuable improvements (UX, performance, coverage)
- P3 — Low: Nice-to-have, backlog grooming candidates

Record the proposal owner and a tentative release target next to the priority.

---

## Example proposal: Canvas-style Survey Builder (seeded from spec)

- Title: Survey Builder (Canvas-like) — Admin Survey Management
- Author / Date: seeded from .copilot-instruction.md — 2025-10-20
- Summary: Admins can create and manage surveys with categories and questions using a dynamic builder UI. The builder supports multiple question types (short answer, multiple choice, likert/scale, evidence uploads), reordering, and audit logging for admin actions.
- Motivation: Replace manual survey construction with a user-friendly editor to reduce admin errors and speed survey creation.

### User stories
- As an Admin, I want to create a new survey with multiple categories and questions so I can collect standardized responses from students.
- As an Admin, I want to reorder questions and categories so I can organize surveys logically.
- As an Admin, I want to preview the survey in student mode so I can verify the student experience before publishing.
- As a Developer, I want each admin change to create an audit log so we can track and revert destructive actions.

### Acceptance Criteria
- Admins can create/edit surveys with categories and questions.
- Questions support types: short_answer, multiple_choice, scale, evidence (file upload) and required flag.
- Surveys can be assigned to tracks (Residential, Executive) and archived (is_active = false).
- Each admin action (create, update, assign, archive, delete) creates a `SurveyChangeLog` record.
- Preview mode renders the survey as students see it (read-only).

### Data model / migrations
- `surveys` table: title:string, description:text, is_active:boolean (default true), created_by:references (User)
- `categories` table: name:string, survey:references
- `questions` table: category:references, question_text:text, response_type:string, is_required:boolean, has_evidence_field:boolean, position:integer
- `survey_assignments` table: survey:references, track:string
- `survey_change_logs` table: admin:references (User), survey:references, action:string, description:text, created_at:datetime

### API / endpoints (high level)
- Admin surveys controller: index, new, create, edit, update, archive, destroy
- Categories nested under surveys: create/update/destroy/reorder
- Questions nested under categories: create/update/destroy/reorder
- Assignments controller for assigning surveys to tracks
- Audit logs controller (read-only for admins)

### UI / interaction notes
- Use Turbo (frames/streams) + Stimulus for dynamic inline editing, or React if already enabled in the project.
- Drag-and-drop reordering for categories/questions (use native HTML5 drag drop or a lightweight library).
- Inline validation and autosave (with optimistic UI feedback).
- Preview mode (read-only) that renders the survey using the same view partials students see.

### Security / permissions
- Only users with role `admin` can manage surveys.
- Advisors have read-only access to view surveys.
- Students only see surveys assigned to their track and can submit responses.

### Tests required
- Model tests for Survey, Category, Question, Assignment, and SurveyChangeLog models
- Controller/integration tests for create/edit/assign/archive flows
- System tests for the builder UI (reordering, creating questions, preview mode)

### Rollout & migration notes
- Seed two sample surveys for verification in staging
- Migrations should include foreign key constraints and `dependent: :destroy`
- Add indexes on foreign keys and position fields for ordering

### Dependencies
- Active Storage (evidence uploads)
- Stimulus / Turbo (preferred) or React (if already present)
- Pundit or CanCanCan for authorization

### Rough estimate
- Size: XL (UI + backend, system tests) — break into smaller milestones:
  1. Data model + basic CRUD (S)
  2. Nested categories/questions + assignments (M)
  3. Builder UI + reordering (L)
  4. Autosave, preview, audit log (L)
  5. System tests & polish (M)

### Implementation checklist
- [ ] Add models & migrations
- [ ] Add model tests and fixtures
- [ ] Implement controllers & routes
- [ ] Implement basic CRUD views
- [ ] Implement nested categories/questions UI
- [ ] Add ordering (position) + drag-drop in UI
- [ ] Implement preview mode
- [ ] Implement SurveyChangeLog entries on each admin action
- [ ] Add system tests for builder interactions
- [ ] Seed sample surveys for staging

---

## Template for recording progress (per proposal)

Use the following status fields at the top of each proposal when work begins:

- Status: proposed / planned / in-progress / blocked / done
- Owner: @github_handle
- Sprint/Milestone: (e.g., Sprint 12)
- Notes: ongoing notes, links to PRs, or blockers


## Maintenance & grooming

- Move proposals that have no owner or traction to the backlog (archive in this file with a date).
- Use GitHub Projects or Issues to track implementation tasks and PRs; link those items into the proposal section.

---

Last updated: 2025-10-20
