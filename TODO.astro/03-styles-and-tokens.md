# 03: Styles & Tokens

Port CSS files directly — no framework change needed (Tailwind v4):
- `src/styles/global.css` → `src/styles/global.css` (keep @import "tailwindcss", @theme, @layer)
- `src/styles/components.css` → `src/styles/components.css`
- `src/styles/tokens.css` → `src/styles/tokens.css`
- Remove the `.vitepress` comment in tokens.css
- Import global.css in BaseLayout.astro `<head>`

Dark mode: `:root[data-theme="dark"]` overrides stay in global.css — same mechanism.
Status variables (`--status-ok/warn/error/info/neutral`) stay unchanged.
