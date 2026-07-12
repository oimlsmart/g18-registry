import { defineConfig } from "astro/config";
import vue from "@astrojs/vue";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath, URL } from "node:url";

const base = "/concepts-management";

export default defineConfig({
  site: "https://www.oimlsmart.org",
  base: `${base}/`,
  integrations: [vue()],
  redirects: {
    "/vocab-gaps": `${base}/analysis/gaps/`,
    "/g18/digital": `${base}/g18/dynamic/`,
    "/leaderboard": `${base}/analysis/divergence/`,
    "/proposals": `${base}/analysis/gaps/`,
    "/actions": `${base}/analysis/actions/`,
    "/harmonization": `${base}/analysis/designations/`,
    "/conflicts": `${base}/g18/conflicts/`,
    "/editions": `${base}/g18/editions/`,
    "/terms": `${base}/concepts/`,
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
