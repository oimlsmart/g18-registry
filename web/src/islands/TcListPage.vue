<script setup lang="ts">
import { computed, ref } from "vue";
import tcData from "@/data/tc.json";
import terms from "@/data/terms.json";
import SLink from "@/components/SLink.vue";

type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");

// Per-edition counts: a term "belongs to" an edition if any of its pub
// instances under this TC/SC are in that edition. Publications similarly.
function pubTermsForEdition(name: string, edition: string | null) {
  return (terms as any[]).filter(t =>
    t.publications.some((p: any) =>
      p.tc_sc === name && (edition === null || p.edition === edition)
    )
  );
}
function termCount(name: string, edition: string | null) {
  return pubTermsForEdition(name, edition).length;
}
function pubCount(name: string, edition: string | null) {
  return new Set(
    (terms as any[]).flatMap(t => t.publications).filter((p: any) =>
      p.tc_sc === name && (edition === null || p.edition === edition)
    ).map((p: any) => p.publication_id)
  ).size;
}

const editionForFilter = computed<string | null>(() =>
  editionFilter.value === "all" ? null : editionFilter.value
);

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
          <td class="num">{{ pubCount(t, editionForFilter) }}</td>
          <td class="num">{{ termCount(t, editionForFilter) }}</td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>
</template>
