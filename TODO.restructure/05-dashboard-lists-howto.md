# 05 — Dashboard, concepts list, and HowToUse updates

## Dashboard (DashboardPage.vue)
- Show V1/V2/OIML corpus breakdown
- Show 5-case alignment distribution (aligned / historic / diverges / fuzzy / none)
- Remove G18-specific stats from homepage

## Concepts list (TermsListPage.vue)
- Add "Alignment" column with 5-case badge
- Add alignment filter dropdown
- Remove G18# column (G18 is detail-page-only metadata)

## HowToUse (HowToUsePage.vue)
- Document all 5 cases with card styling
- Each case: what it means, what to do, example

## Dashboard data (export_for_vite.rb)
```ruby
"alignment_counts" => { "aligned" => N, "historic" => N, "diverges" => N, "fuzzy" => N, "none" => N },
"corpus_v1_concepts" => <viml-2022 count>,
"corpus_v2_concepts" => <vim-2012 count>,
```
