<script setup lang="ts">
import { ref, computed } from "vue";
import publications from "@/data/publications.json";
import terms from "@/data/terms.json";
import { slugifyPubId } from "@/composables/useSuggestedActions";

type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");
const sortByProblems = ref(false);

const editionForFilter = computed<string | null>(() =>
  editionFilter.value === "all" ? null : editionFilter.value
);

const filtered = computed(() => {
  let pubs = publications as any[];
  if (editionForFilter.value) {
    // Only show publications that have at least one term in the selected edition.
    const pubIds = new Set<string>();
    for (const t of terms as any[]) {
      if (t.editions_present?.includes(editionForFilter.value)) {
        for (const p of t.publications || []) {
          if (p.edition === editionForFilter.value && p.publication_id) {
            pubIds.add(p.publication_id);
          }
        }
      }
    }
    pubs = pubs.filter(p => pubIds.has(p.id));
  }
  if (sortByProblems.value) {
    pubs = [...pubs].sort((a, b) => problemCount(b.id) - problemCount(a.id) || (b.year || 0) - (a.year || 0));
  }
  return pubs;
});

function termCount(pubId: string, ed: string | null) {
  return (terms as any[]).filter(t =>
    t.publications.some((p: any) =>
      p.publication_id === pubId && (ed === null || p.edition === ed)
    )
  ).length;
}

// Terms under a publication that are "problematic": divergent definitions
// (≥2 distinct defs), outdated VIM refs, modified adoptions, or ID-conflicting.
function problemTerms(pubId: string, ed: string | null): any[] {
  const out: any[] = [];
  for (const t of terms as any[]) {
    const pubs = (t.publications || []).filter((p: any) =>
      p.publication_id === pubId && (ed === null || p.edition === ed)
    );
    if (pubs.length === 0) continue;
    const dd = new Set(t.publications
      .filter((p: any) => ed === null || p.edition === ed)
      .map((p: any) => (p.definition || "").trim()).filter(Boolean)).size;
    const lc = t.latest_check;
    const modifiedCount = pubs.filter((p: any) => p.source?.relationship === "modified").length;
    const reasons: string[] = [];
    if (dd >= 2) reasons.push(`${dd} distinct defs`);
    if (lc && !lc.found) reasons.push(`cites superseded edition`);
    if (lc && lc.found && t.official_concept && lc.concept_id !== t.official_concept.id) reasons.push(`concept id mismatch`);
    if (modifiedCount > 0) reasons.push(`${modifiedCount} modified adoption${modifiedCount > 1 ? "s" : ""}`);
    if (reasons.length) out.push({ name: t.name, slug: t.slug, reasons });
  }
  return out;
}

function problemCount(pubId: string): number {
  return problemTerms(pubId, editionForFilter.value).length;
}

// Per-edition pub counts for the filter button meta text.
const editionPubCounts = computed(() => {
  const c = { "202X": 0, "2010": 0 };
  for (const ed of ["202X", "2010"] as const) {
    const pubIds = new Set<string>();
    for (const t of terms as any[]) {
      for (const p of t.publications || []) {
        if (p.edition === ed && p.publication_id) pubIds.add(p.publication_id);
      }
    }
    c[ed] = (publications as any[]).filter(p => pubIds.has(p.id)).length;
  }
  return c;
});
</script>
<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Publications</span></div>
    <h1>Publications</h1>
    <p class="lede">{{ (publications as any[]).length }} publications. Default scope: 202X (draft, TC 1 acts here).</p>
  </div>

  <!-- Sticky page-level edition filter -->
  <div class="page-filter" role="region" aria-label="Edition filter">
    <span class="page-filter-label">Edition scope</span>
    <div class="page-filter-controls">
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
              @click="editionFilter = '202X'">
        <span class="page-filter-btn-title">202X</span>
        <span class="page-filter-btn-meta">{{ editionPubCounts["202X"] }} pubs · draft, TC 1 acts here</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
              @click="editionFilter = '2010'">
        <span class="page-filter-btn-title">2010</span>
        <span class="page-filter-btn-meta">{{ editionPubCounts["2010"] }} pubs · historic, read-only</span>
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
      <label class="sort-toggle-label">
        <input type="checkbox" v-model="sortByProblems" />
        Sort by problematic terms first
      </label>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>
    <div class="table-scroll">
      <table>
      <thead><tr><th>Reference</th><th>Year</th><th>TC/SC</th><th>Terms ({{ editionFilter === "all" ? "all" : editionFilter }})</th><th v-if="sortByProblems">Problematic</th></tr></thead>
      <tbody>
        <tr v-for="p in filtered" :key="p.id">
          <td><SLink :to="`/publications/${slugifyPubId(p.id)}/`">{{ p.reference || p.id }}</SLink></td>
          <td class="num">{{ (p.id || '').match(/(\d{4})/)?.[1] || "—" }}</td>
          <td><SLink :to="`/tc/${(p.tc_sc || '').toLowerCase().replace('/', '-').toLowerCase()}/`">{{ p.tc_sc || "—" }}</SLink></td>
          <td class="num">{{ termCount(p.id, editionForFilter) }}</td>
          <td v-if="sortByProblems" class="num">
            <span v-if="problemCount(p.id)" class="problem-count">{{ problemCount(p.id) }}</span>
            <span v-else class="muted">—</span>
          </td>
        </tr>
      </tbody>
    </table>
    </div>

    <section v-if="sortByProblems" class="pub-problem-detail">
      <h2>Problematic terms per publication</h2>
      <details v-for="p in filtered.filter(x => problemCount(x.id) > 0)" :key="p.id" class="pub-problem-block">
        <summary>
          <strong>{{ p.reference || p.id }}</strong>
          <span class="muted"> — {{ problemCount(p.id) }} term(s)</span>
        </summary>
        <ul>
          <li v-for="pt in problemTerms(p.id, editionForFilter)" :key="pt.slug">
            <SLink :to="`/terms/${pt.slug}/`">{{ pt.name }}</SLink>
            <span class="muted"> — {{ pt.reasons.join('; ') }}</span>
          </li>
        </ul>
      </details>
    </section>
  </section>
</template>
