# 32 — useEditionFilter composable has zero consumers

## Finding
`web/src/composables/useEditionFilter.ts` exists but is not imported
by any island. Only the `EditionFilter` TYPE is imported by
`EditionFilterButtons.vue` (which itself is on the chopping block —
G 18 filters are being removed per TODO 04).

The actual edition filter logic is duplicated inline across 5 islands
(see TODO 29). The composable was created but never wired up.

## Options
1. **Wire it up**: migrate the 5 islands to use the composable (TODO 29)
2. **Delete it**: remove the composable and EditionFilterButtons
3. **Add a test + leave as-is**: lock in behavior pending TODO 29

This session: option 3 (add a test) — keeps the door open for TODO 29
without forcing a wide refactor.
