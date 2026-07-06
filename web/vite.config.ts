import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath, URL } from "node:url";

export default defineConfig({
  // The site is served at a subpath, not root.
  base: "/g18-registry/",
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  // Vite-SSG config: prerender all routes listed in `includedRoutes`
  // at build time. The actual list is generated below from the data
  // files written by scripts/export_for_vite.rb.
  ssgOptions: {
    script: "async",
    formatting: "minify",
    includedRoutes: async (paths, routes) => {
      // Default: every static page.
      const fs = await import("node:fs");
      const dataDir = fileURLToPath(new URL("./src/data", import.meta.url));
      const dynamic = [];
      for (const sub of ["terms", "publications", "tc"]) {
        try {
          const list = JSON.parse(fs.readFileSync(`${dataDir}/${sub}.json`, "utf-8"));
          for (const item of list) {
            // Handle three shapes:
            //   - terms/tc-by-slug objects: { slug: "..." }
            //   - publications: { id: "..." } (no slug) → slugify the id
            //   - tc.json as a flat array of display-name strings: "CEEMS"
            let slug: string | undefined;
            if (typeof item === "string") {
              slug = item.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
            } else if (item.slug) {
              slug = item.slug;
            } else if (item.id) {
              // Publications: slugify the id so URLs don't contain spaces
              // or special characters (e.g. "OIML R 76-1:2006" → "oiml-r-76-1-2006").
              slug = item.id.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
            }
            if (slug) dynamic.push(`/${sub}/${slug}/`);
          }
        } catch (_) { /* data file may not exist yet */ }
      }
      return [...paths, ...dynamic];
    },
  },
});
