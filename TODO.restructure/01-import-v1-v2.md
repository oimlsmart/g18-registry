# 01 — Import V1/V2 as first-class corpus terms

## Context
V1 (VIML) and V2 (VIM) are authoritative OIML vocabularies. Currently they're only used as matching targets at export time — not imported as concepts in the corpus. Importing them directly enables the full 5-case decision tree.

## Datasets to import
- viml-2022 (136 concepts, current V1) — primary
- viml-2013 (136, historic)
- viml-2000 (45, historic)
- vim-2012 (145 concepts, current V2) — primary
- vim-2007 (145, historic)
- vim-1993 (121, historic)
- Skip viml-1968 (276 concepts, French-only — use only in historic matching)

## Changes
1. `scripts/migrate_from_vocab.rb`: add V1/V2 editions with `:vocab` metadata
2. `lib/g18/migration/runner.rb`: thread `:vocab` through entries
3. `lib/g18/migration/builders.rb`: `pick_official()` fallback to `:vocab` when no `see` edges
4. Verify: ~3000 terms (2700 oiml + 136 + 145 minus overlaps)

## Key constraint
V1/V2 concepts use `related: supersedes` and `related: compare` edges (NOT `see`). The `pick_official` function needs a fallback path using the `:vocab` field.
