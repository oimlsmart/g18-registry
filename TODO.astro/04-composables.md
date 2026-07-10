# 04: Composables

Port all TypeScript composables to plain `.ts` modules under `src/lib/`:
They contain pure business logic — no Vue dependency except `ref`/`computed`.

- `useSuggestedActions.ts` → `src/lib/actions.ts` (drop `useSuggestedActions` wrapper; export plain functions)
- `usePagination.ts` → `src/lib/pagination.ts` (drop ref wrapper; accept plain array + page state)
- `useGapProposal.ts` → `src/lib/gapProposal.ts` (drop Vue; pure functions)
- `useVocabGaps.ts` → `src/lib/vocabGaps.ts` (import JSON directly)
- `useTheme.ts` → inline in layout `<script>` (no module needed)
- `useVocabularyEdition.ts` → `src/lib/vocabulary.ts`

Tests: copy `*.test.ts` files alongside. All 57 tests must pass.
For reactive state in Astro pages: use `<script>` islands or Vue components for
interactive parts (filters, pagination, modals).
