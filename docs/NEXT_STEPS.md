# Next Steps

## Priority order

This list is intentionally short. It is meant to help the next owner choose useful work quickly.

## Urgent

### 1. Add smoke tests for grade imports

Focus on:

- mapping workbook import
- direct competency import
- duplicate suppression
- pending-row reconciliation
- dry run commit
- rollback

Why:

- this is the highest-risk admin workflow

### 2. Add clearer operator guidance on the batch results page

Examples:

- label when a file was detected as direct competency import
- explain why rows are pending versus failed
- call out when course ratings are not semester-scoped

Why:

- reduces admin confusion without changing data behavior

## Next

### 3. Break up `GradeImports::BatchProcessor`

Suggested split:

- file router
- direct competency parser
- Canvas parser
- narrow parser
- mapping parser / validator

Why:

- easier testing
- safer future changes

### 4. Add more sample import files

Include:

- successful direct competency import with real identifiers
- duplicate-upload example
- pending-row example
- intentionally bad mapping example

Why:

- makes troubleshooting and onboarding much easier

### 5. Improve competencies usability further

Potential improvements:

- sticky domain summary or quick-jump links
- export filtered matrix
- remembered filter state

Why:

- admins use this page to answer targeted questions quickly

## Later

### 6. Add true semester support for course ratings

This likely requires storing semester or term context on imported course ratings/evidence.

Why:

- would align course data behavior with self/advisor filtering

### 7. Continue admin UI cleanup

Focus on:

- reducing nested containers
- making action language more explicit
- standardizing dense detail pages

Why:

- polish work matters most in the admin experience

### 8. Consolidate cross-source competency logic

Self, advisor, and course competency views now exist in multiple places.

Why:

- reduces duplication
- keeps behavior consistent across reports, student records, and admin competencies
