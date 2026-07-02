import type { RouteRecordRaw } from "vue-router";

export const routes: RouteRecordRaw[] = [
  { path: "/", component: () => import("./pages/index.vue") },
  { path: "/actions/", component: () => import("./pages/actions.vue") },
  { path: "/terms/", component: () => import("./pages/terms/index.vue") },
  { path: "/terms/:slug/", component: () => import("./pages/terms/[slug].vue"), props: true },
  { path: "/publications/", component: () => import("./pages/publications/index.vue") },
  { path: "/publications/:slug/", component: () => import("./pages/publications/[slug].vue"), props: true },
  { path: "/tc/", component: () => import("./pages/tc/index.vue") },
  { path: "/tc/:slug/", component: () => import("./pages/tc/[slug].vue"), props: true },
  { path: "/editions/", component: () => import("./pages/editions.vue") },
  { path: "/harmonization/", component: () => import("./pages/harmonization.vue") },
  { path: "/conflicts/", component: () => import("./pages/conflicts.vue") },
  { path: "/leaderboard/", component: () => import("./pages/leaderboard.vue") },
];
