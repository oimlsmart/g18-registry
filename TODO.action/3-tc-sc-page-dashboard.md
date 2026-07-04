# 3 — TC/SC page: aggregated committee dashboard

## Audience
TC/SC secretaries.

## What to show
When a secretary visits `/tc/<their-tc>/`, they see:

### Dashboard tiles
- **Total publications** under this TC/SC
- **Terms needing action** (across all their publications)
- **Clean publications** (no action needed)
- **Publications with issues** (list)

### Per-publication breakdown
Table showing each publication under this TC/SC:
- Publication name + year
- Total terms in this pub
- Terms needing action (count)
- Terms clean (count)
- Status badge: "Clean" / "Needs attention"
- Link to publication detail page

### Suggested actions
For each publication with issues, list:
- "3 terms cite superseded VIM — upgrade to VIM 2012"
- "2 terms have divergent definitions — harmonize with TC 1"
- "1 term not in latest VIML — verify or reallocate"

## Implementation
- Requires per-publication action counts (from TODO 1 + 2).
- TC/SC page already exists at `/tc/[slug]/`; extend with dashboard.
- Aggregate action counts by iterating all terms and filtering to
  this TC/SC's publications.
