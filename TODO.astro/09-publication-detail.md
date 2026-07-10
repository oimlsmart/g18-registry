# 09: Publication Detail (`/publications/[slug]/`)

Port `web/src/pages/publications/[slug].vue` → `src/pages/publications/[slug].astro`:
- getStaticPaths() from publications.json + slugifyPubId
- Edition filter (202X/2010/All) with per-edition counts
- Summary tiles (Terms needing action / Clean / Total)
- Per-action-type breakdown list
- Terms needing action table (view modes: by-action/by-clause/A-Z)
- Action icon legend
- Clean terms table
- All titles use pub.reference (not generic "G 18")
