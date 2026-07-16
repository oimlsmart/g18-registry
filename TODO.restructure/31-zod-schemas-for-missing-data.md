# 31 — Zod schemas for missing data files

## Context
`web/src/data/schemas.ts` has schemas for terms, publications, vocab-gaps,
edition-stats. Missing:
- dashboardSchema (dashboard.json — ~30 fields, used by DashboardPage)
- conflictsSchema (conflicts.json — raw + designation_collisions)
- harmonizationSchema (harmonization.json — array of terms)
- termsSlimSchema (terms-slim.json — subset of termSchema fields)

## Plan
- Add the 4 schemas to schemas.ts
- Add data-contracts.test.ts entries for each
- (Optional) Use the schemas in islands to derive types instead of `any`

## Why
- Locks in data contracts at the schema level
- Catches export-pipeline regressions before they hit the UI
- Enables TypeScript type inference in islands
