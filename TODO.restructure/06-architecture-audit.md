# 06 — Architecture audit and improvements

## Context
The codebase has evolved rapidly. Audit for OCP, DRY, MECE, encapsulation, performance, and single-source-of-truth violations.

## Known issues to address

### 1. Migration: glossarist parse failures
- `lib/g18/migration/loaders.rb` strips sources before parsing to avoid lutaml-model errors
- This is a hack. The glossarist gem needs updating, or the migration should use glossarist-js (Node.js) for ALL concept parsing instead of the Ruby gem
- **Action**: Evaluate migrating all concept parsing to glossarist-js via Node subprocess

### 2. Export script is monolithic (999 lines)
- `scripts/export_for_vite.rb` does: publication loading, relaton enrichment, lifecycle computation, sourced_from enrichment, matching, action compilation, dashboard stats, per-entity file generation
- **Action**: Extract into modules: `G18::Export::Publications`, `G18::Export::Matching`, `G18::Export::Actions`, `G18::Export::Dashboard`

### 3. Publication lifecycle duplicated
- Lifecycle is computed in `export_for_vite.rb` but also referenced in multiple Vue components
- **Action**: Single source of truth in publications.json; Vue reads from there

### 4. Per-term JSON key inconsistency
- Per-publication JSON now uses `publications` (was `instances`) but some code may still reference old names
- **Action**: Audit all `.json` field access for consistency

### 5. Terms-slim lacks per-edition identifiers
- G18 entry numbers vary across editions; only one identifier is stored
- **Action**: Store per-edition identifiers as a map: `{"2010": "00242", "202X": "00147"}`

### 6. Ref access bugs in detail pages
- Recurring pattern: converting from static import to ref() but missing `.value` on some accesses
- **Action**: Comprehensive grep audit of all ref access patterns

### 7. Missing specs
- No Ruby specs for migration, matching, or action compilation
- No Vue component specs for detail pages
- **Action**: Add spec/ directory with migration specs, matching specs, compiler specs

### 8. G18 edition references scattered
- Multiple files hardcode "202X", "2010", "complete" edition names
- **Action**: Centralize edition names as constants

## OCP compliance check
- Adding a new action type should require: 1 entry in Action::TYPES, 1 entry in ACTION_META, 1 method in Compiler. Currently requires touching 3+ files.
- Adding a new edition should require: 1 entry in migrate_from_vocab.rb. Currently requires updating edition name lists in multiple Vue components and test files.

## Performance audit
- terms-slim.json (2.3MB) is loaded on concepts list — could be paginated server-side
- Per-term fetch works well; per-publication fetch works well
- Dashboard.json (3KB) is optimal
- Consider: pre-computing alignment results as per-term JSON fields (no runtime computation needed)
