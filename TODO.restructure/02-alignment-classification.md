# 02 — 5-case alignment classification

## Context
Each OIML-specific concept needs to be classified against V1/V2 concepts by comparing BOTH designation AND definition. This replaces the current `check_vocab_presence` which only checks designation.

## The 5 cases
1. **Aligned**: designation + definition identical to current V1/V2 → no action
2. **Historic match**: matches historic V1/V2 (not current) → update citation
3. **Definition diverges**: designation matches current, definition differs → adopt or differentiate
4. **Fuzzy match**: fuzzy designation match → user decides
5. **No match**: no V1/V2 match → propose V3

## Changes
1. `scripts/export_for_vite.rb`: build historic V1/V2 indices for Case 2
2. New `classify_alignment()` function replacing `check_vocab_presence`
3. Definition normalization: strip `{{...}}`, collapse whitespace, strip punctuation
4. Wire into export loop, store as `alignment` on each term
5. Add to `terms-slim.json`: `alignment_case` (1-5) and `alignment_status`

## Key constraint
Fuzzy match (Case 4) only checks current editions. Historic editions (Case 2) use exact match only. Performance: ~2700 oiml terms × ~290 V1/V2 designations for fuzzy = manageable.
