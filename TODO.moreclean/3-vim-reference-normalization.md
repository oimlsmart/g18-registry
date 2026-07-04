# 3 — VIM reference normalization + cross-reference linking

## Problem
VIM 2012 definitions use inline reference markup like:
```
{{3.1,measuring instrument}}
```
This means "see VIM concept 3.1 (measuring instrument)". When comparing
VIM 2007 (plain text) vs VIM 2012 (with references), the definitions
appear different but are semantically identical — the only change is the
introduction of cross-references.

## Two fixes needed

### A. Normalize for comparison
Strip the `{{id,text}}` wrapper before comparing definition text, so
VIM 2007 and VIM 2012 definitions match when the only difference is
reference markup.

Regex: `{{[\d.]+,([^}]+)}}` → `$1`

Apply in:
- The "match against authoritative" indicator on per-term pages
- The definition-grouping logic (group identical definitions)
- The harmonization/definition-conflicts divergence count

### B. Render references as links
When displaying definition text, convert `{{id,text}}` to:
```html
<a href="/terms/<slugified-text>/" class="xref">text</a>
```

Apply in:
- Authoritative definition card
- Publication instances table (definition column)
- Definition group cards

The link points to the G18 registry term matching the referenced text
(e.g. `{{3.1,measuring instrument}}` → `/terms/measuring-instrument/`).

## Scope
- Migration/export: add normalized_definition field alongside definition
- UI: new `<DefText>` component that renders `{{id,text}}` as links
- Comparison logic: use normalized_definition for matching/grouping
