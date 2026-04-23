# Known Issues

## Grade imports

### Direct competency files require real student identifiers

The direct competency format expects:

- `Student SIS ID`
- or `Student ID`

If those values are blank, the importer cannot match or stage students correctly.

Impact:

- rows fail with missing identifier errors

### Course ratings are not semester-scoped at the storage layer

`Admin > Competencies` supports a semester filter for self and advisor data.

Course ratings currently use the latest reportable imported values and are not truly filtered by semester because the grade import ratings do not store semester separately.

Impact:

- users may assume course values are semester-filtered when they are not

Current mitigation:

- the page explicitly explains this in the summary copy

### Grade import processor is large

[app/services/grade_imports/batch_processor.rb](/home/rainsuds/codespace/MHA-Survey-Portal/app/services/grade_imports/batch_processor.rb) handles:

- batch orchestration
- file format detection
- direct competency import
- Canvas import
- narrow import
- mapping parsing
- duplicate protection

Impact:

- harder to maintain
- higher regression risk when changing import behavior

## UI / admin surface area

### Admin still has the densest workflow surface

The admin experience is much better organized than before, but it still has the most complex operational surface in the system.

High-complexity areas:

- grade imports
- survey builder
- reports
- competencies view

Impact:

- onboarding takes time
- small UX regressions matter more here

## Testing coverage

There is existing test documentation, but the highest-risk areas would still benefit from more dedicated smoke tests:

- grade imports
- pending reconciliation
- competencies filtering
- dry run commit / rollback

Impact:

- future refactors may break operational workflows without obvious early signals

## Data and environment

### Seeded local data may not reflect production behavior

Many admin/import workflows behave best against a realistic production clone because:

- seeded students are limited
- import matching depends heavily on real UINs / IDs / accounts

Impact:

- a feature can look broken locally when the issue is actually data mismatch

## Documentation dependency

The README points to the GitHub wiki for broader documentation.

Impact:

- some knowledge may still live outside the repo
- future owners should keep repo docs and wiki docs in sync
