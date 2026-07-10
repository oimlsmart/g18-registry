# 18: Dynamic Routes (SSG)

Astro's `getStaticPaths()` replaces vite-ssg's `includedRoutes`:
- `/terms/[slug]/` → paths from terms.json slugs
- `/publications/[slug]/` → paths from publications.json via slugifyPubId
- `/tc/[slug]/` → paths from tc.json via slugify
- Redirect `/vocab-gaps/` → `/proposals/`
