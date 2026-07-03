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
            // publications.json uses `id`; terms/tc use `slug`.
            const slug = item.slug || item.id;
            if (slug) dynamic.push(`/${sub}/${slug}/`);
          }
        } catch (_) { /* data file may not exist yet */ }
      }
      return [...paths, ...dynamic];
    },
  },
});
