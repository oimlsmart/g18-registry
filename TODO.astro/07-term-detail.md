# 07: Term Detail (`/terms/[slug]/`)

Port `web/src/pages/terms/[slug].vue` → `src/pages/terms/[slug].astro`:
- getStaticPaths() generates all term pages from terms.json
- Page-head with term name (DefText for MathML), kind badge, match status
- Historic callout (2010-only)
- Sticky edition filter
- VIM/VIML concept comparison (upgrade/removed/current states) — uses ConceptBody
- Operative definition card (OIML-original terms)
- Designations section
- Provenance analysis
- Publication instances table (definition groups, flat mode toggle)
- Full concept from vocab repo (designations, definitions, notes, examples, lang toggle)

Complex interactivity: wrap in Vue island or split into Astro + client components.
