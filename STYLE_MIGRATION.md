# CSS Common Assets Migration

This app currently loads multiple split Propshaft stylesheets in a fixed order (see layouts).

## New common assets

- [app/assets/stylesheets/05_common_assets.css](app/assets/stylesheets/05_common_assets.css)

This file introduces reusable building blocks that only use existing CSS variables from:

- `00_tokens_utilities.css` (design tokens)
- `60_components_accessibility.css` (high-contrast overrides)

So high-contrast mode continues to work because it strengthens the same variables.

## How to migrate gradually

Prefer adding **new** classes in templates instead of rewriting existing page CSS.

Recommended mapping:

- Page shell
  - wrap page content with `.c-page`
  - use `.c-page-header`, `.c-page-title`, `.c-page-subtitle`

- Cards
  - use `.c-card` (and optional modifiers `.c-card--tight`, `.c-card--interactive`)

- Forms
  - use `.c-field`, `.c-label`, `.c-input`, `.c-help`, `.c-error`

- Tables
  - use `.c-table-wrapper` + `.c-table`

- Buttons
  - keep using the existing button system: `btn` + `btn-primary|btn-secondary|...`

## Notes

- Do not hard-code new colors in page CSS. Prefer the existing variables (e.g. `var(--primary-color)`, `var(--gray-700)`).
- If a component needs a high-contrast tweak, prefer variable-driven styles; if necessary add a specific `body.high-contrast ...` rule.
