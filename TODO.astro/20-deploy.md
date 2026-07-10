# 20: Deploy

Update `.github/workflows/deploy.yml`:
- Replace `pnpm run build` (vite-ssg) with `astro build`
- Output path: `dist/` (Astro default)
- Upload Pages artifact from `dist/`
- Verify base path `/g18-registry/` in astro.config.mjs
- All vitest tests must pass in CI before deploy
- Smoke test: curl key pages after deploy
