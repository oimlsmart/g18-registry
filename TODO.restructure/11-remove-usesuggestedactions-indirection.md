# 11 — Remove useSuggestedActions re-export indirection

## Context
`web/src/composables/useSuggestedActions.ts` re-exports 11 symbols from
`action-utils.ts` for "backward compatibility". This made sense when
migrating, but now it just means two import paths for the same thing.

## Plan
1. Find all imports from `@/composables/useSuggestedActions`
2. Replace with direct imports from `@/composables/action-utils` (or `@/utils/term-utils` for slugify)
3. Keep only the `useSuggestedActions()` composable function in the file
4. Update tests to import from the canonical location

## Migration map
| Old import | New import |
|------------|------------|
| `slugifyPubId` from useSuggestedActions | `slugify` from `@/utils/term-utils` |
| `ACTION_META`, `actionMeta`, `PRIORITY_RANK` from useSuggestedActions | same from `@/composables/action-utils` |
| `isOimlOriginal` from useSuggestedActions | `isOimlSpecific` from `@/utils/edition-utils` |

## After migration
The file shrinks from 112 lines to ~85 lines and contains only the composable.
