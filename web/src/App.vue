<script setup lang="ts">
import { useRoute } from "vue-router";

const route = useRoute();
const base = import.meta.env.BASE_URL; // "/g18-registry/" in prod, "/" in dev
const logoSrc = `${base}oiml-logo.svg`;
const navItems = [
  { to: "/actions/", label: "Actions" },
  { to: "/terms/", label: "Terms" },
  { to: "/tc/", label: "TC / SC" },
  { to: "/publications/", label: "Publications" },
  { to: "/editions/", label: "Editions" },
  { to: "/harmonization/", label: "Harmonise" },
  { to: "/conflicts/", label: "ID Conflicts" },
  { to: "/leaderboard/", label: "Divergence" },
];
const isActive = (path: string) => path === "/" ? route.path === "/" : route.path.startsWith(path);
</script>

<template>
  <header class="site-header">
    <div class="container header-bar">
      <a class="brand" :href="base">
        <img :src="logoSrc" alt="OIML" class="brand-mark-img" />
        <span class="brand-sub">
          <span class="brand-sub-title">G 18 Registry</span>
          <span class="brand-sub-tag">OIML Term-Usage Registry</span>
        </span>
      </a>
      <nav class="site-nav">
        <RouterLink v-for="n in navItems" :key="n.to" :to="n.to" :class="{ 'router-link-active': isActive(n.to) }">{{ n.label }}</RouterLink>
      </nav>
    </div>
  </header>
  <main class="container main">
    <RouterView />
  </main>
  <footer class="site-footer">
    <div class="container footer-grid">
      <div>
        <strong>G 18 — OIML Term-Usage Registry</strong><br />
        Source: <a href="https://github.com/oimlsmart/vocab/tree/main/datasets/g18-2010">oimlsmart/vocab</a>.
        VIM/VIML: <a href="https://oimlsmart.github.io/vocab/">oimlsmart.github.io/vocab</a>.
      </div>
      <div class="footer-attribution">
        <strong>OIML SMART.</strong> Digital service by <a href="https://www.ribose.com">Ribose</a>.
      </div>
    </div>
  </footer>
</template>

<style>
@import "./styles/global.css";
@import "./styles/components.css";
</style>
