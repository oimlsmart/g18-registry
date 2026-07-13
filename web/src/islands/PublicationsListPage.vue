<script setup lang="ts">
import { ref, computed } from "vue";
import publications from "@/data/pub-list.json";
import { slugifyPubId } from "@/composables/useSuggestedActions";
import SLink from "@/components/SLink.vue";

type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");

const editionForFilter = computed<string | null>(() =>
  editionFilter.value === "all" ? null : editionFilter.value
);

function termCount(pub: any): number {
  if (editionForFilter.value) {
    return pub.edition_term_counts?.[editionForFilter.value] || 0;
  }
  return pub.term_count || 0;
}

const filtered = computed(() => {
  const pubs = publications as any[];
  if (editionForFilter.value) {
    return pubs.filter(p => (p.edition_term_counts?.[editionForFilter.value] || 0) > 0);
  }
  return pubs;
});
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Publications</span></div>
    <h1>Publications</h1>
    <p class="lede">{{ (publications as any[]).length }} publications. Default scope: G 18:202X (draft, TC 1 acts here).</p>
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
        <span class="page-filter-btn-meta">{{ (publications as any[]).length }} pubs · both editions</span>
      </button>
    </div>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>
    <div class="table-scroll">
      <table>
      <thead><tr><th>Reference</th><th>Year</th><th>TC/SC</th><th>Terms ({{ editionFilter === "all" ? "all" : editionFilter }})</th></tr></thead>
      <tbody>
        <tr v-for="p in filtered" :key="p.id">
          <td><SLink :to="`/publications/${slugifyPubId(p.id)}/`">{{ p.reference || p.id }}</SLink></td>
          <td class="num">{{ (p.id || '').match(/(\d{4})/)?.[1] || "—" }}</td>
          <td><SLink :to="`/tc/${(p.tc_sc || '').toLowerCase().replace('/', '-').toLowerCase()}/`">{{ p.tc_sc || "—" }}</SLink></td>
          <td class="num">{{ termCount(p) }}</td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>
</template>
