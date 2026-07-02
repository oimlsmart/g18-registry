<script setup lang="ts">
const base = import.meta.env.BASE_URL;
const logoSrc = `${base}oiml-logo.svg`;
const navItems = [
  { href: "actions/", label: "Actions" },
  { href: "terms/", label: "Terms" },
  { href: "tc/", label: "TC / SC" },
  { href: "publications/", label: "Publications" },
  { href: "editions/", label: "Editions" },
  { href: "harmonization/", label: "Harmonise" },
  { href: "conflicts/", label: "ID Conflicts" },
  { href: "leaderboard/", label: "Divergence" },
];
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
        <a v-for="n in navItems" :key="n.href" :href="base + n.href">{{ n.label }}</a>
      </nav>
    </div>
  </header>
  <main class="container main">
    <slot />
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
