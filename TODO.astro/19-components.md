# 19: Shared Components

Port Vue components to Astro:
- `SLink.vue` → `SLink.astro` (plain `<a>` with correct base path)
- `DefText.vue` → `DefText.astro` (renders MathML + cross-refs; may need client JS for link click)
- `PaginationControls.vue` → `PaginationControls.astro` (needs interactivity → Vue island)
- `ConceptBody.vue` → `ConceptBody.astro` (renders designations/definitions/notes — mostly static)
- Logo images: `oiml-logo.svg`, `oiml-logo-dark.svg` → `public/`
