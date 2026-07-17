# 35 — Final state summary (2026-07-17)

## Total PRs opened across 4 audit rounds: 20

### Round 1 — Initial audit (#137-#142)
- #137 alignment_action specs
- #138 export god object split into 12 modules
- #139 migration + vocabulary specs (52 new)
- #140 concept detail: G 18 filter removed + V1/V2 card moved up
- #141 HowToUse rewrite for 5-case model
- #142 edition-utils applied across islands

### Round 2 — Deeper audit (#143-#149)
- #143 dead action types removed (adopt_vim/viml/update_citation)
- #144 slugify/isOiml consolidated + useSuggestedActions re-exports dropped
- #145 Actions::Compiler OCP refactor (strategy pattern via Rules::ALL)
- #146 lib/g18.rb autoload tree, dropped 7 require_relative
- #147 ConceptDiffer + SourcedFromEnricher specs
- #148 RecommendationBanner extracted from TermDetailPage
- #149 audit summary TODOs (10-22)

### Round 3 — Type safety + integration (#150-#154)
- #150 DRY action type ordering + drop dead adopt_* refs
- #151 ConceptDiffView + DecisionFlowSVG specs (18 examples)
- #152 Pipeline integration spec (10 examples, end-to-end)
- #153 G18::Model::PubId extracted from Loaders (MECE)
- #154 Zod schemas for dashboard/conflicts/harmonization/slim + useEditionFilter spec

### Round 4 — Performance + safety (#155-#156)
- #155 drop dead JSON files (45MB savings) + TcSc specs (27 new)
- #156 pipeline minimum-output guard (catches silent data-loss)

## Architectural state achieved

### Backend
- **lib/g18.rb** — top-level autoload tree, no `require_relative` for siblings
- **G18::Export::Pipeline** — orchestrator with 12 focused modules; safety
  guard for data-loss detection
- **G18::Actions::Compiler** — 22 lines, OCP-compliant via `Rules::ALL`
- **G18::Model::{Identifier,PubId}** — text utilities in their own namespace
- **G18::Migration::Loaders** — partially decomposed (PubId extracted)
- **G18::Vocabulary** — module of constants; no behavior, no instances

### Frontend
- **action-utils.ts** — single source of truth for ACTION_META,
  ACTION_TYPE_ORDER, PRIORITY_RANK, actionTypeRank, sortByActionType
- **edition-utils.ts** — single source of truth for editionDataName,
  editionUiLabel, isOimlSpecific, sortedEditions
- **term-utils.ts** — single source of truth for slugify, normalizeDef,
  groupProvenance, kindLabel
- **schemas.ts** — Zod schemas for 8 data files (terms, terms-slim,
  publications, vocab-gaps, conflicts, harmonization, edition-stats,
  dashboard)
- **useJsonFetch** — single fetch composable used by 3 detail pages
- **RecommendationBanner** — extracted leaf component (first of N
  planned from TODO 16)

### Data contracts
- 88MB of dead weight identified; 45MB removed (PR #155)
- 43MB more could go (test-only harmonization.json + terms.json)

### Spec coverage
- **Ruby**: 26 → 100+ examples (depending on which branches merge)
- **Frontend**: 179 → 220+ examples

## What remains documented (not executed)

### Requires user judgment
- **TODO 20**: `data/` directory is 2913 generated YAML files; should
  be gitignored. User must decide: keep visible in PRs, or treat as
  derived output.
- **TODO 21**: `lib/g18/site/` + `scripts/build_site.rb` are legacy
  static-renderer code replaced by Astro. User must decide: delete.

### Feature work
- **TODO 18**: Case 2 (historic V1/V2 match detection) — requires
  loading 4 more datasets at export time + adding update_citation
  action type back.

### Large refactors (one-PR-per-step)
- **TODO 16**: TermDetailPage decomposition (Tier 2/3). Pattern
  established in PR #148. Remaining: AuthoritativeConceptCard,
  PublicationCitations, DivergenceSummary, ConceptMetadata.
- **TODO 25**: Full Loaders decomposition. PubId extracted (PR #153);
  further splits require breaking changes to Loaders.foo callers.
- **TODO 28**: ProposalsPage decomposition (615 lines).
- **TODO 29**: Wire useEditionFilter across 5 islands (composable
  exists with locked-in spec; migration is mechanical but wide).

### Performance
- 43MB more dead JSON could be dropped (TODO 34)
- pnpm build ~5s, could be profiled
- ProposalsPage JS bundle >500KB (largest)

## Verification

Each PR has:
- Focused scope (one concern per PR)
- New specs where applicable
- End-to-end build verification (`pnpm build` succeeds)
- Frontend tests run (`pnpm test` 179-220 pass, 3 env-dependent failures)

## How to merge

Recommended merge order (least-conflict first):
1. Documentation-only: #149, #141
2. Test-only: #137, #139, #147, #151, #152, #154
3. Backend refactors: #138, #145, #146, #153, #156
4. Frontend refactors: #142, #143, #144, #150, #148, #140
5. Performance: #155

Each PR's commit message documents dependencies and verification steps.
