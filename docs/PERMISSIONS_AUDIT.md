# Permissions Audit

## Purpose

This document records the current permission assumptions and the highest-value checks completed during handoff hardening.

It is not a formal security review. It is an operational audit note for the next maintainer.

## Admin-only areas reviewed

The following surfaces are intended to be admin-only:

- `Admin::*` controllers via `Admin::BaseController`
- `People Management`
- `Program Configuration`
- `Grade Import Batches`
- `Competencies`
- survey builder admin flows

## Current guard pattern

`Admin::BaseController` enforces:

- admin users may continue
- advisor users are redirected to dashboard with `Access denied`
- student users are redirected to dashboard without an admin warning

`DashboardsController` uses `ensure_admin!` for dashboard-based admin workspaces such as:

- `people_management`
- member role changes
- student assignment changes

## Coverage added in this handoff pass

Automated tests now cover:

- `Admin::GradeImportBatchesController` admin-only access
- `Admin::CompetenciesController` admin-only access
- batch commit / rollback / recommit behavior
- `GradeImportBatch.reportable` scope behavior

Existing tests already cover:

- `manage_members`
- `manage_students`
- major survey admin flows

## Practical expectations by role

### Student

Should not be able to access:

- admin pages
- people management
- grade import
- competencies admin review

Students usually get a silent redirect to dashboard for admin URLs.

### Advisor

Should not be able to access:

- admin pages
- grade import batches
- admin competencies page
- people management write actions

Advisors typically receive an `Access denied` alert when blocked.

### Admin

Should be able to access:

- all admin pages
- grade import controls
- people management
- competencies review

## Residual risks to verify later

- dashboard actions outside the `Admin::` namespace can be easier to miss during code review
- future feature additions may forget to reuse `Admin::BaseController` or `ensure_admin!`
- deeper export/download actions should be rechecked when new endpoints are added

## Suggested follow-up

When time allows, add a broader request-spec style matrix for:

- student blocked from all admin routes
- advisor blocked from all admin routes
- admin allowed through all admin routes
