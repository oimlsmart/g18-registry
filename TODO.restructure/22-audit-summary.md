# 22 — Architecture audit summary (2026-07-16)

## What was audited
Full sweep of `lib/g18/`, `scripts/`, `web/src/`, `spec/`, and the
build pipeline.

## Issues addressed in this session
- ✅ TODO 10: dead action types removed (PR #143)
- ✅ TODO 11+12+13: frontend duplication consolidated (PR #144)
- ✅ TODO 14: lib/g18.rb autoload tree (PR #146)
- ✅ TODO 15: Actions::Compiler OCP refactor (PR #145)
- ✅ TODO 17: ConceptDiffer + SourcedFromEnricher specs (PR #147)
- ✅ TODO 19: V1/V2 card moved above banner (PR #140, 2nd commit)
- ✅ TODO 16 (partial): RecommendationBanner extracted (PR #148)

## Issues documented but not addressed
- ⚠️ TODO 16 (remaining): Tier 2/3 TermDetailPage decomposition — large
  multi-day refactor. Pattern established; recommend one-PR-per-extraction.
- ⚠️ TODO 18: Case 2 (historic V1/V2 match) — feature work, requires
  loading 4 more datasets at export time.
- ⚠️ TODO 20: `data/` directory is 2913 generated YAML files committed
  to git. Should be gitignored + generated in CI.
- ⚠️ TODO 21: `lib/g18/site/` static renderer appears to be dead code
  from pre-Astro era. Needs user judgment to delete.

## Specs added this session
| Branch | Spec count |
|--------|-----------|
| refactor/ocp-actions-compiler | 48 (TermState + 5 rules) |
| test/export-module-specs | 9 (ConceptDiffer + SourcedFromEnricher) |
| refactor/extract-recommendation-banner | 5 (component test) |
| (existing PRs #137-#142) | 81 |

Ruby suite: 26 → 74 examples on main; +48 on OCP branch; +9 on export-module-specs
Frontend suite: 179 → 184 passing (excluding 3 env-dependent failures).

## Architectural state after this session
- **lib/g18/**: properly autoloaded; no require_relative for siblings;
  single entry point at `lib/g18.rb`.
- **Actions::Compiler**: 22 lines; strategy pattern via Rules::ALL;
  adding rules = adding files (OCP).
- **G18::Export::\***: 12 focused modules under `lib/g18/export/`,
  each independently testable.
- **Frontend utils**: `slugify` and `isOimlSpecific` have single homes
  in `web/src/utils/`.
- **Action types**: no dead declarations; backend TYPES matches
  frontend ACTION_META exactly.

## Open PRs (this session)
- #137 test/alignment-action-specs
- #138 refactor/export-modularization (export god object split)
- #139 test/migration-specs
- #140 feat/concept-detail-redesign (G 18 filter removal + V1/V2 first)
- #141 docs/how-to-use-5case
- #142 refactor/frontend-cleanup (edition-utils applied)
- #143 refactor/remove-dead-action-types
- #144 refactor/frontend-consolidation (slugify/isOiml)
- #145 refactor/ocp-actions-compiler
- #146 refactor/lib-g18-autoload
- #147 test/export-module-specs
- #148 refactor/extract-recommendation-banner
