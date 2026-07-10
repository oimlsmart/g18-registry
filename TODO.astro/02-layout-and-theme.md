# 02: Layout & Theme

Port `web/src/App.vue` → `src/layouts/BaseLayout.astro`:
- Header: logo (light/dark), "OIML Terminology Harmonization" title, nav (primary + More dropdown), theme toggle
- Footer: logo, source links, Ribose credit
- Theme toggle: vanilla JS `<script>` reading localStorage + prefers-color-scheme
- Apply `data-theme` on `<html>` before paint (inline script in `<head>`)
- Active nav highlighting: compare `Astro.url.pathname` against nav items
- Mobile hamburger: CSS + minimal JS toggle

Files to port:
- `App.vue` → `BaseLayout.astro`
- `useTheme.ts` → inline `<script>` in layout (no Vue reactivity needed)
- Logo SVGs: copy to `public/`
