<script setup lang="ts">
import { computed, ref } from "vue";
import tcData from "@/data/tc.json";
import terms from "@/data/terms.json";
import publicationsData from "@/data/publications.json";
import { slugifyPubId } from "@/composables/useSuggestedActions";
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

// Publications with TC/SC from publications.json (relaton-enriched).
// Term instances may lack tc_sc but the publication itself may have one.
const pubTcScMap = computed(() => {
  const map: Record<string, string> = {};
  for (const p of (publicationsData as any[])) {
    if (p.tc_sc) map[p.id] = p.tc_sc;
  }
  return map;
});

// Publications that have terms in the selected edition but no TC/SC
// assignment anywhere — either a data quality issue (wrong pubid in
// relaton) or genuinely unassigned.
const unassignedPubs = computed(() => {
  const ed = editionForFilter.value;
  const ids = new Set<string>();
  for (const t of (terms as any[])) {
    if (ed && !(t.editions_present || []).includes(ed)) continue;
    for (const p of (t.publications || [])) {
      if (ed && p.edition !== ed) continue;
      if (!p.publication_id) continue;
      const tcSc = p.tc_sc || pubTcScMap.value[p.publication_id] || "";
      if (!tcSc || tcSc.trim() === "") {
        ids.add(p.publication_id);
      }
    }
  }
  return [...ids].sort();
});

const unassignedTermCount = computed(() => {
  const ed = editionForFilter.value;
  const unassignedIds = new Set(unassignedPubs.value);
  return (terms as any[]).filter(t =>
    t.publications.some((p: any) =>
      p.publication_id &&
      unassignedIds.has(p.publication_id) &&
      (ed === null || p.edition === ed)
    )
  ).length;
});

const showUnassigned = ref(false);

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

  <!-- Unassigned publications warning — at top so data quality issues are visible immediately -->
  <div v-if="unassignedPubs.length" class="unassigned-banner" @click="showUnassigned = !showUnassigned">
    <span class="unassigned-banner-label">Not assigned to any TC</span>
    <span class="unassigned-banner-count">{{ unassignedPubs.length }} publications, {{ unassignedTermCount }} terms</span>
    <span class="unassigned-banner-hint">{{ showUnassigned ? "▾ hide" : "▸ show list" }} — likely wrong pubid or missing from relaton-data-oiml</span>
  </div>
  <div v-if="showUnassigned && unassignedPubs.length" class="unassigned-list">
    <ul class="unassigned-pubs">
      <li v-for="pid in unassignedPubs" :key="pid">
        <SLink :to="`/publications/${slugifyPubId(pid)}/`">{{ pid }}</SLink>
      </li>
    </ul>
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

<style scoped>
.unassigned-banner {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 0.4em 0.8em;
  padding: 0.7em 1em;
  margin-bottom: 1em;
  background: var(--status-warn-bg);
  border: 1px solid var(--status-warn-border);
  border-left: 4px solid var(--status-warn-border);
  border-radius: var(--radius-card);
  cursor: pointer;
  transition: background 0.15s;
}
.unassigned-banner:hover {
  background: color-mix(in srgb, var(--status-warn-bg) 85%, var(--color-paper));
}
.unassigned-banner-label {
  font-weight: 700;
  color: var(--status-warn-text);
  font-size: 0.92rem;
}
.unassigned-banner-count {
  font-weight: 600;
  color: var(--status-warn-text);
  font-size: 0.88rem;
}
.unassigned-banner-hint {
  font-size: 0.8rem;
  color: var(--color-ink-muted);
}
.unassigned-list {
  padding: 0.7em 1em;
  margin-bottom: 1em;
  background: var(--status-warn-bg);
  border: 1px solid var(--status-warn-border);
  border-top: none;
  border-radius: 0 0 var(--radius-card) var(--radius-card);
}
.unassigned-pubs {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 0.3em 1em;
}
.unassigned-pubs li {
  font-size: 0.84rem;
  font-family: var(--font-mono);
}
</style>
