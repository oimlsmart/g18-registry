# 19 — Move V1/V2 authoritative concept card above recommendation banner

## Context
TODO 04 §1 asked for the authoritative V1/V2 concept to be the PRIMARY
focus at the top of the concept detail page. Currently it sits below
the recommendation banner, withdrawn warning, publication citations,
and historic-only callout.

## Plan
- Move the `<section class="card" v-if="showConceptCard || canPropose">` block
  to immediately after the page-head, before the recommendation banner
- Adjust spacing/CSS so the visual hierarchy reads: page-head → authoritative concept → recommendation → everything else

## Why
The authoritative concept is the anchor for Cases 1/3/4 — everything
below is compared against it. Showing it first sets context for the
recommendation banner.
