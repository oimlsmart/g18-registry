# 18 — Implement Case 2 (historic V1/V2 match detection)

## Context
The 5-case alignment classification currently handles cases 1, 3, 4, 5.
Case 2 (matches a historic V1/V2 edition that's no longer in current) is
documented but not implemented.

## What Case 2 means
An OIML publication cites a VIM/VIML concept by designation, and that
designation exists in (e.g.) VIM 2007 but NOT in VIM 2012. The concept
was removed/renamed in the latest edition.

This is distinct from the existing `vocab_actions` which fires when a
term has an `official_concept` URN pointing to an old edition. Case 2
specifically handles OIML-original terms whose designation matches a
historic concept.

## Plan
1. Load historic indices for vim-{1993,2007} and viml-{2000,2013} at export time
2. In classify_alignment, add Case 2 check: if not in current but in historic, return case=2
3. Compiler produces `update_citation` action (un-comment from action.rb TYPES)
4. UI surfaces Case 2 with a distinct color
5. HowToUsePage already documents Case 2 (done in PR #141)

## Out of scope for this session
Requires loading 4 more datasets (~1-2s additional export time). Feature work.
