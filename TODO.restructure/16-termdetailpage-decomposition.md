# 16 — Decompose TermDetailPage.vue (1971 lines)

## Status
**In progress.** Pattern established in PR #148 (RecommendationBanner
extraction). TermDetailPage is now 1924 lines (was 1971).

## Context
The concept detail page is a single Vue component with 8+ distinct
sections. Goal: extract each as a child component with explicit prop
types and a dedicated test file.

## Established pattern (PR #148)
1. Identify a self-contained section with clear prop inputs
2. Create `web/src/components/<Name>.vue` with explicit TypeScript prop types
3. Move related CSS into the child's `<style scoped>`
4. Write a `<Name>.test.ts` with `@vue/test-utils` `mount()` — fast, no Astro
5. Replace inline template in parent with `<Name :prop="value" />`

## Extraction queue (in priority order)

### Tier 1 — leaf components (low risk, no upstream state)
- [x] **RecommendationBanner** — DONE (PR #148)
- [ ] **PublicationCitations** — table of pub_id → citation status
- [ ] **ConceptMetadata** — G 18 entry IDs, lifecycle, sourced-from chips
- [ ] **WithdrawnWarning** — withdrawn publication callout

### Tier 2 — medium complexity (some derived state)
- [ ] **DivergenceSummary** — definition-group cards; needs `definitionGroups`
- [ ] **AuthoritativeConceptCard** — V1/V2 comparison; takes `term` and many
  derived flags. Largest single extraction.

### Tier 3 — composable extraction
- [ ] `useTermDetail()` — holds the fetched `term` ref + all derived computeds
  (recommendation, pubCitations, definitionGroups, etc.). Passes shared state
  via `provide/inject` so children don't prop-drill.

## Why decompose
- Each piece testable in isolation (vitest unit tests, not browser smoke)
- Clear single responsibility per component
- Reduces Vue re-render scope
- Enables parallel work — multiple people can edit different components

## Risk
Vue prop-drilling can be painful. Mitigation: Tier 3 composable + provide/inject.

## Out of scope for this session
Tier 2/3 extractions require careful refactoring of computed properties.
Recommend doing one extraction per PR to keep diffs reviewable.
