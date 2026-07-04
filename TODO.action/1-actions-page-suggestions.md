# 1 — Actions page: per-term upgrade/adopt suggestions

## Audience
TC 1 / Vocabularies (primary). Also surfaces on per-publication and
per-TC/SC pages.

## What to show
For each term that has an `official_concept` (VIM/VIML citation),
compute suggested actions:

### Action types
1. **Upgrade to latest VIM** — term cites VIM 1993/2007/2010 but
   exists in VIM 2012 (the latest). Suggest: "Cites VIM 2007 §4.11;
   available in VIM 2012 §4.11. Upgrade citation."
   - Data needed: `latest_check.found` + `latest_check.latest_label`
   - Condition: `latest_check.found === true` AND official_concept
     cites a non-current edition

2. **Upgrade to latest VIML** — term cites VIML 1968/2000/2013 but
   exists in VIML 2022. Same pattern.

3. **Adopt VIM definition** — term is NOT in VIM but IS defined in
   VIML (or vice versa). Suggest adopting the authoritative definition
   from the other vocabulary.
   - Condition: term.kind is "defined_in_vim" but latest_check in VIML
     finds it (or vice versa)

4. **Term no longer in latest** — term was in older VIM/VIML but has
   been removed from the latest edition.
   - Condition: `latest_check.found === false`
   - Action: "Cites superseded edition; term not found in VIM 2012.
     Verify if still needed or reallocate."

5. **Harmonize definitions** — term has ≥ 2 distinct definitions.
   Already covered by Defn Conflicts page.

### Layout
Current Actions page already has priority worklist. Extend with:
- "Upgrade" tag on terms citing superseded editions
- "Adopt" tag on terms that could adopt from the other vocabulary
- "Removed" tag on terms not in latest

## Implementation
- Compute actions in `export_for_vite.rb` at export time (not
  client-side — pre-compute for static rendering).
- Add `suggested_actions[]` to each term in terms.json.
- Actions page renders them grouped by type.
