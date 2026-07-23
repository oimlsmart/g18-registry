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
    "/g18/concepts": `${base}/concepts/`,
    "/g18/digital": `${base}/concepts/`,
    "/g18/dynamic": `${base}/concepts/`,
    "/g18/current": `${base}/concepts/`,
    "/leaderboard": `${base}/analysis/divergence/`,
    "/proposals": `${base}/analysis/gaps/`,
    "/actions": `${base}/analysis/actions/`,
    "/harmonization": `${base}/g18/designations/`,
    "/analysis/designations": `${base}/g18/designations/`,
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
