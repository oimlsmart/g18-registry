# 1 — Mobile table header/body misalignment

## Problem
On mobile, tables use `display: block; overflow-x: auto` which makes the
`<table>` itself the scroll container. Inside it, `<thead>` and `<tbody>`
become independent `display: table` elements — they compute column widths
**separately**, so columns drift out of alignment when scrolled.

## Root cause
```css
/* BROKEN — thead and tbody become independent table-layout contexts */
table { display: block; overflow-x: auto; }
thead, tbody { display: table; width: 100%; min-width: max-content; }
```

## Fix
Wrap each table in `<div class="table-scroll">` in templates. The div is
the scroll container; the table stays as `display: table` so the browser
computes column widths across thead+tbody together.

```css
.table-scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; }
```

Pages with tables to wrap:
- terms/index.vue (terms list)
- terms/[slug].vue (publication instances, definition groups, provenance)
- actions.vue (priority worklist)
- conflicts.vue (conflict list)
- harmonization.vue (worklist)
- editions.vue (comparison table)
- publications/index.vue (publications list)
- publications/[slug].vue (terms in publication)
- tc/index.vue (TC list)
- tc/[slug].vue (TC detail)
- index.vue (dashboard stats, priority actions)
