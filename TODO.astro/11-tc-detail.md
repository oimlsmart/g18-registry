# 11: TC Detail (`/tc/[slug]/`)

Port `web/src/pages/tc/[slug].vue` → `src/pages/tc/[slug].astro`:
- getStaticPaths() from tc.json
- Sticky edition filter
- Summary tiles
- Per-publication status table
- Suggested actions table (view modes: by-action/by-pub/A-Z)
- Action icon legend
- Publications column (which doc each term is from)
- All terms table
