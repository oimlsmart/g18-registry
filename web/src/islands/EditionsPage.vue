<script setup lang="ts">
import { computed } from "vue";
import editionStats from "@/data/edition-stats.json";

// Always show 202X first — TC 1 edits 202X; 2010 is historic.
const sortedEditions = computed(() =>
  [...(editionStats.editions || [])].sort((a: string, b: string) =>
    (b === "202X" ? 1 : 0) - (a === "202X" ? 1 : 0)
  )
);
const sortedStats = computed(() =>
  [...(editionStats.stats || [])].sort((a: any, b: any) =>
    (b.edition === "202X" ? 1 : 0) - (a.edition === "202X" ? 1 : 0)
  )
);
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Editions</span></div>
    <h1>Edition comparison</h1>
    <p class="lede">OIML G 18:202X (draft, TC 1 is validating this) vs G 18:2010 (published, historic reference).</p>
  </div>
  <section class="card">
    <div class="table-scroll">
      <table>
      <thead><tr><th>Edition</th><th v-for="e in sortedEditions" :key="e">{{ e }}<span v-if="e === '202X'" class="badge badge-ok" style="margin-left:0.4em">draft</span><span v-if="e === '2010'" class="muted" style="margin-left:0.4em">historic</span></th></tr></thead>
      <tbody>
        <tr><td>Source concepts</td><td v-for="s in sortedStats" :key="s.edition" class="num">{{ s.instances }}</td></tr>
        <tr><td>Unique terms</td><td v-for="s in sortedStats" :key="s.edition" class="num">{{ s.terms }}</td></tr>
        <tr><td>Only in this edition</td><td v-for="s in sortedStats" :key="s.edition" class="num">{{ s.only_in_edition }}</td></tr>
        <tr><td>Harmonisation candidates</td><td v-for="s in sortedStats" :key="s.edition" class="num">{{ s.harmonization_candidates }}</td></tr>
      </tbody>
    </table>
    </div>
  </section>
  <section class="card">
    <h2>What changed between editions</h2>
    <ul>
      <li><SLink to="/harmonization/">Definition conflicts worklist →</SLink></li>
      <li><SLink to="/terms/?only=2010-only">Terms removed: in 2010 but deleted in 202X →</SLink></li>
      <li><SLink to="/terms/?only=202X-only">Terms added: new in 202X, not in 2010 →</SLink></li>
      <li><SLink to="/conflicts/">ID conflicts (numbering errors) →</SLink></li>
    </ul>
  </section>
</template>
