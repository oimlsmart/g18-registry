# 13 — Dashboard page cleanup

## Context
`DashboardPage.vue` has confusing dead-code aliases:
```ts
const vocabGaps = dashboard;
const terms = dashboard;
```
Both alias the same `dashboard` import. Remove them; use `dashboard` directly.

## Plan
- Inline `vocabGaps` and `terms` aliases
- Verify no other dead bindings
