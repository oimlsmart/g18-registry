import { ViteSSG } from "vite-ssg";
import App from "./App.vue";
import { routes } from "./routes";
import SLink from "./components/SLink.vue";
import DefText from "./components/DefText.vue";
import PaginationControls from "./components/PaginationControls.vue";
import { initTheme } from "./composables/useTheme";

export const createApp = ViteSSG(
  App,
  { routes, base: "/g18-registry/" },
  ({ app }) => {
    app.component("SLink", SLink);
    app.component("DefText", DefText);
    app.component("PaginationControls", PaginationControls);
  },
);

// Apply theme after hydration to avoid SSG/client mismatch. The SSG
// pre-render assumes light theme (no data-theme attribute); the client
// switches to the user's preferred theme as soon as it mounts.
if (typeof window !== "undefined") {
  initTheme();
}
