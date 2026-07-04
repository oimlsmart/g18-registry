# 2 — Publications page: action list for project teams

## Audience
Recommendation project teams (authors of OIML R/D publications).

## What to show
When a project team member visits `/publications/<their-pub>/`, they
see a per-publication action list sorted by term:

### Sections
1. **Terms to adopt VIM/VIML definition** — terms where this pub's
   definition differs from the authoritative VIM/VIML text.
   Suggest: "Adopt VIM 2012 §4.11 definition."

2. **Terms to upgrade** — terms citing superseded VIM/VIML editions.
   Suggest: "Upgrade citation from VIM 2007 to VIM 2012."

3. **Terms unique to this publication** — OIML-original terms not
   found in VIM/VIML. These are this pub's contribution to G 18.

4. **Terms needing harmonization** — terms where this pub's definition
   diverges from other publications citing the same term.

5. **Terms that are clean** — terms matching VIM/VIML verbatim.
   No action needed.

### Sorting
Sort by term name (alphabetical) within each section. Total count
per section at the top.

## Implementation
- Requires `suggested_actions[]` per term (from TODO 1).
- Publication page filters actions to only this pub's terms.
- Add a summary tile card: "X terms need action, Y are clean."
