# 01: Project Setup

- `npm create astro@latest` in `web/` (or sibling `astro/`)
- Install `@astrojs/vue` for Vue island components (ConceptBody, DefText need reactivity)
- Install `@astrojs/tailwind` or keep `@tailwindcss/vite` (v4)
- Install `@astrojs/sitemap`
- Transfer `package.json` deps: keep `vitest`, `happy-dom`; drop `vite-ssg`, `vue-router`
- Configure `astro.config.mjs` with `base: "/g18-registry/"` and `site: "https://www.oimlsmart.org"`
- Move `src/data/*.json` → `src/data/` (same path in Astro)
- Set up `tsconfig.json` with `@` alias → `src/`
- Verify: `astro dev` starts without errors
- Run vitest: all 57 tests must pass
