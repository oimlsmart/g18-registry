# 03 — New action types for 5-case decision tree

## Context
The G18::Actions::Compiler needs new action types that map to the 5 alignment cases.

## Changes
1. `lib/g18/actions/action.rb`: add types: `aligned`, `update_citation`, `definition_diverges`, `fuzzy_adopt`, `propose_v3`
2. `lib/g18/actions/compiler.rb`: new `alignment_action()` method consuming alignment data
3. `web/src/composables/action-utils.ts`: add ACTION_META entries for new types

## Mapping
| Case | Action type | Priority | Description |
|------|------------|----------|-------------|
| 1 | aligned | info | "Aligned with current {vocab}" |
| 2 | update_citation | medium | "Matches historic {edition} — update to current" |
| 3 | definition_diverges | high | "Definition differs from {vocab} — adopt or differentiate" |
| 4 | fuzzy_adopt | medium | "Similar to '{matched}' — adopt or propose V3" |
| 5 | propose_v3 | low | "No V1/V2 match — propose for V3" |

Existing `harmonize`, `retire` actions remain alongside.
