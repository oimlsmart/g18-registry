# 05: Dashboard (`/`)

Port `web/src/pages/index.vue` → `src/pages/index.astro`:
- Page-head with title "OIML Terminology Harmonization" + lede
- Audience cards (4 cards: TC 1, TC/SC secretaries, Publication authors, VIM/VIML maintainers)
- Stat tiles (terms count, divergent, collisions, ID conflicts)
- "How to use this portal" numbered list
- Priority actions table (top 15 from byTerm)
- Most divergent terms table
- Edition comparison table
- Dataset quality cards

All data is pre-computed in JSON — Astro fetches at build time.
Interactive parts (if any): wrap in Vue island components.
