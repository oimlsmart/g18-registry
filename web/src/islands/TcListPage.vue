<script setup lang="ts">
import { computed, ref } from "vue";
import tcData from "@/data/tc.json";
import tcStats from "@/data/tc-stats.json";
import { slugifyPubId } from "@/composables/useSuggestedActions";
import SLink from "@/components/SLink.vue";

type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");

// Build a lookup map from tc-stats.json for O(1) access.
const statsMap = computed(() => {
  const map: Record<string, any> = {};
  for (const s of tcStats as any[]) {
    map[s.tc] = s;
  }
  return map;
});

function termCount(tcName: string): number {
  const s = statsMap.value[tcName];
  if (!s) return 0;
  switch (editionFilter.value) {
    case "202X": return s.terms_202X;
    case "2010": return s.terms_2010;
    default: return s.terms_total;
  }
}

function pubCount(tcName: string): number {
  const s = statsMap.value[tcName];
  if (!s) return 0;
  switch (editionFilter.value) {
    case "202X": return s.pubs_202X;
    case "2010": return s.pubs_2010;
    default: return s.pubs_total;
  }
}

function slug(name: string) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>TC / SC</span></div>
    <h1>Technical Committees</h1>
    <p class="lede">{{ (tcData as string[]).length }} subcommittees. Default scope: G 18:202X (draft, TC 1 acts here).</p>
  </div>

  <!-- Sticky page-level edition filter -->
  <div class="page-filter" role="region" aria-label="G 18 edition filter">
    <span class="page-filter-label">G 18 edition</span>
    <div class="page-filter-controls">
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
              @click="editionFilter = '202X'">
        <span class="page-filter-btn-title">G 18:202X</span>
        <span class="page-filter-btn-meta">draft, TC 1 acts here</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
              @click="editionFilter = '2010'">
        <span class="page-filter-btn-title">G 18:2010</span>
        <span class="page-filter-btn-meta">historic, read-only</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' }]"
              @click="editionFilter = 'all'">
        <span class="page-filter-btn-title">All</span>
        <span class="page-filter-btn-meta">both editions</span>
      </button>
    </div>
  </div>

  <section class="card">
    <div class="table-scroll">
      <table>
      <thead><tr><th>TC / SC</th><th>Publications ({{ editionFilter === "all" ? "all" : editionFilter }})</th><th>Terms ({{ editionFilter === "all" ? "all" : editionFilter }})</th></tr></thead>
      <tbody>
        <tr v-for="t in (tcData as string[])" :key="t">
          <td><SLink :to="`/tc/${slug(t)}/`">{{ t }}</SLink></td>
          <td class="num">{{ pubCount(t) }}</td>
          <td class="num">{{ termCount(t) }}</td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>
</template>
