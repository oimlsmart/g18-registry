<script setup lang="ts">
import editionStats from "@/data/edition-stats.json";
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Editions</span></div>
    <h1>Edition comparison</h1>
    <p class="lede">Side-by-side view of OIML G 18:2010 (published) and G 18:202X (draft, being validated by TC 1).</p>
  </div>
  <section class="card">
    <table>
      <thead><tr><th>Edition</th><th v-for="e in editionStats.editions" :key="e">{{ e }}</th></tr></thead>
      <tbody>
        <tr><td>Source concepts</td><td v-for="s in editionStats.stats" :key="s.edition" class="num">{{ s.instances }}</td></tr>
        <tr><td>Unique terms</td><td v-for="s in editionStats.stats" :key="s.edition" class="num">{{ s.terms }}</td></tr>
        <tr><td>Only in this edition</td><td v-for="s in editionStats.stats" :key="s.edition" class="num">{{ s.only_in_edition }}</td></tr>
        <tr><td>Harmonisation candidates</td><td v-for="s in editionStats.stats" :key="s.edition" class="num">{{ s.harmonization_candidates }}</td></tr>
      </tbody>
    </table>
  </section>
  <section class="card">
    <h2>What changed between editions</h2>
    <ul>
      <li><SLink to="/harmonization/">Harmonisation worklist →</SLink></li>
      <li><SLink to="/terms/?only=2010-only">Terms removed: in 2010 but deleted in 202X →</SLink></li>
      <li><SLink to="/terms/?only=202X-only">Terms added: new in 202X, not in 2010 →</SLink></li>
      <li><SLink to="/conflicts/">ID conflicts →</SLink></li>
    </ul>
  </section>
</template>
