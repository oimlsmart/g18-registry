# User Feedback — Term Detail Page Issues

Source: user review of /terms/adjustment/ (2026-07-11)

## Already fixed (PR #77)
- [x] 01: Remove cross-edition drift block
- [x] 02: Fix latest_check fuzzy match (concept-ID + fuzzy fallback in export script)
- [x] 03: Hide Designations for simple VIM/VIML terms
- [x] 04: Fix provenance label "OIML-original Authoritative" → "No VIM/VIML citation"

## Remaining issues

- [ ] 05: Fix R 142-1:2025 source data (cites V 2-200:2007, should be V 2-200:2012)
- [ ] 06: Add R 142-1:2025 to publications.yaml (currently causes 404 link)
- [ ] 07: Fix "aquantity" typo in R 99-1:2008 definition data
- [ ] 08: latest_check still false in deployed data (needs CI pipeline run with updated export script)
- [ ] 09: Clarify "2 distinct definitions" display (it's a typo difference, not real divergence)
- [ ] 10: Improve provenance grouping to group by cited VIM edition (2012 vs 2007)
