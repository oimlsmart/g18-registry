import { ViteSSG } from "vite-ssg";
import App from "./App.vue";
import { routes } from "./routes";
import SLink from "./components/SLink.vue";
import DefText from "./components/DefText.vue";

export const createApp = ViteSSG(
  App,
  { routes, base: "/g18-registry/" },
  ({ app }) => {
    app.component("SLink", SLink);
    app.component("DefText", DefText);
  },
);
