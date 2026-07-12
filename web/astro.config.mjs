import { defineConfig } from "astro/config";
import vue from "@astrojs/vue";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath, URL } from "node:url";

export default defineConfig({
  site: "https://www.oimlsmart.org",
  base: "/concepts-management/",
  integrations: [vue()],
  redirects: {
    "/vocab-gaps": "/analysis/gaps",
    "/g18/digital": "/g18/dynamic",
    "/leaderboard": "/analysis/divergence",
    "/proposals": "/analysis/gaps",
    "/actions": "/analysis/actions",
    "/harmonization": "/analysis/designations",
    "/conflicts": "/g18/conflicts",
    "/editions": "/g18/editions",
  },
  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: {
        "@": fileURLToPath(new URL("./src", import.meta.url)),
      },
    },
  },
});
