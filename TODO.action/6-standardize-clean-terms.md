# 6 — "Standardize this concept" page (clean terms)

## Audience
TC 1 / Vocabularies.

## What to show
A new page (or section on Defn Conflicts) listing terms that are
**clean** — cited by ≥ 2 publications with identical definitions
and no conflicts. TC 1 can batch-confirm these as canonical for 202X.

### Layout
- Tile summary: "X terms are clean and ready for standardization."
- Table: term name, # publications, definition text (truncated),
  VIM/VIML citation (if any).
- Per-row action: "Standardize" → marks the term as confirmed.

### Implementation
- Filter terms where:
  - publications.length >= 2
  - distinctDefs == 1 (all publications share the same definition)
  - No ID conflicts
- This is a subset of the harmonization analysis already computed.
- Could be a filter on the Defn Conflicts page: "Show clean terms"
  toggle, or a separate page in the nav.
