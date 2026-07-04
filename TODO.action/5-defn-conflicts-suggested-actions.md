# 5 — Defn Conflicts page: harmonization with suggested actions

## Audience
TC 1 (primary). Also surfaces suggested actions for the relevant
TC/SC/project teams.

## What to show
Current page lists terms with divergent definitions. Enhance each
entry with:

### Per-term suggested action
- "This term has N distinct definitions across M publications.
  TC 1 should decide: merge into one canonical definition, or
  document why divergence is intentional."
- Link to the term page for side-by-side comparison.
- List the TC/SCs responsible for the divergent publications
  (so TC 1 knows who to contact).

### Additional sections
1. **Terms needing harmonization** (current content, enhanced)
2. **Terms with no conflicts** — terms cited by ≥ 2 publications
   with identical definitions. TC 1 can "standardize" these
   (confirm the definition as canonical for 202X).
   - Show a "Standardize" action button (or link to a workflow).
   - These are the easy wins — no editorial work needed, just
     formal confirmation.

## Implementation
- Terms with no conflicts: filter where distinctDefs == 1 AND
  publications.length >= 2.
- Per-term suggested action: pre-compute at export time.
- Responsible TC/SCs: extract from publication.tc_sc field.
