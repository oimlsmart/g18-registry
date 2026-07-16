# 12 — Consolidate slugify and isOiml* helpers

## Context
Two slugify functions exist:
- `slugify(s)` in `web/src/utils/term-utils.ts`
- `slugifyPubId(id)` in `web/src/composables/action-utils.ts` — just calls `slugify`

Two isOiml* helpers exist:
- `isOimlOriginal(term)` in action-utils — takes a term object
- `isOimlSpecific(kind)` in edition-utils — takes a kind string

Both pairs do the same thing. Consolidate.

## Plan
- Remove `slugifyPubId`; migrate all callers to `slugify`
- Remove `isOimlOriginal`; migrate callers to `isOimlSpecific(t.kind)`
- Single source of truth in `utils/edition-utils.ts`
