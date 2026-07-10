<script setup lang="ts">
import { ref, computed } from "vue";
import harmonization from "@/data/harmonization.json";
import conflictsData from "@/data/conflicts.json";
import termsData from "@/data/terms.json";
import { usePagination } from "@/composables/usePagination";
import { maxWithinEditionDistinctDefs } from "@/composables/useSuggestedActions";
import SLink from "@/components/SLink.vue";
import PaginationControls from "@/components/PaginationControls.vue";
import { kindLabel, slugify, isHistoricTerm } from "@/utils/term-utils";

// Build a name → kind lookup for VIM/VIML column in collision table.
const termKindMap: Record<string, string> = {};
for (const t of termsData as any[]) {
  if (t.name) termKindMap[t.name.toLowerCase()] = t.kind;
}
function termKind(designation: string): string | undefined {
  return termKindMap[designation.toLowerCase()];
}

type SortKey = "divergence" | "citations" | "name";
const sort = ref<SortKey>("divergence");
const search = ref("");

// Use the shared per-edition max helper from useSuggestedActions. The local
// `distinctDefs` is now a thin alias so existing call sites stay readable
// (the worklist column header reads "Distinct defs").
function distinctDefs(pubs: any[]): number {
  return maxWithinEditionDistinctDefs(pubs);
}
function distinctDefsAll(pubs: any[]): number {
  // Cross-edition count — used by the "Ready to standardize" check, where
  // we want to know if every pub (anywhere) uses identical wording.
  return new Set(pubs.map(p => (p.definition || "").trim()).filter(Boolean)).size;
}
function tcscList(pubs: any[]): string {
  const set = new Set(pubs.map(p => p.tc_sc).filter(Boolean));
  return Array.from(set).sort().join(", ");
}

// Per-edition distinct def count for a single edition (used by edition filter).
function distinctDefsInEdition(pubs: any[], edition: string): number {
  return new Set(
    pubs.filter(p => (p.edition || "(unspecified)") === edition)
        .map(p => (p.definition || "").trim())
        .filter(Boolean)
  ).size;
}

// Edition filter: scope worklist to a single edition. 202X = TC 1's work;
// 2010 = historic conflicts (can't fix, only document); All = both.
type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");

const rows = computed(() => {
  let list = (harmonization as any[])
    .map(t => {
      const d202X = distinctDefsInEdition(t.publications, "202X");
      const d2010 = distinctDefsInEdition(t.publications, "2010");
      return {
        ...t,
        _defs: editionFilter.value === "2010" ? d2010 : d202X,  // drives display
        _defs202X: d202X,
        _defs2010: d2010,
        _pubs: t.publications.length,
      };
    })
    // Show only terms that have within-edition divergence IN the selected
    // edition. (All view shows terms divergent in either edition.)
    .filter(t => {
      if (editionFilter.value === "202X") return t._defs202X >= 2;
      if (editionFilter.value === "2010") return t._defs2010 >= 2;
      return t._defs202X >= 2 || t._defs2010 >= 2;
    });
  if (search.value) {
    const q = search.value.toLowerCase();
    list = list.filter(t => t.name?.toLowerCase().includes(q));
  }
  const sortFn: Record<SortKey, (a: any, b: any) => number> = {
    divergence: (a, b) => b._defs - a._defs || b._pubs - a._pubs || (a.name || "").localeCompare(b.name || ""),
    citations:  (a, b) => b._pubs - a._pubs || b._defs - a._defs || (a.name || "").localeCompare(b.name || ""),
    name:       (a, b) => (a.name || "").localeCompare(b.name || ""),
  };
  return [...list].sort(sortFn[sort.value]);
});

// Total per-edition counts for the filter button meta text.
const editionCounts = computed(() => {
  const c = { "202X": 0, "2010": 0 };
  for (const t of (harmonization as any[])) {
    if (distinctDefsInEdition(t.publications, "202X") >= 2) c["202X"]++;
    if (distinctDefsInEdition(t.publications, "2010") >= 2) c["2010"]++;
  }
  return c;
});

const pagination = usePagination(rows, {
  pageSize: 50,
  dep: () => `${sort.value}|${search.value}|${editionFilter.value}`,
});

const topDivergent = computed(() => [...rows.value].sort((a, b) => b._defs - a._defs || b._pubs - a._pubs).slice(0, 20));

// Terms ready to standardize: cited by ≥ 2 pubs, all definitions identical
// (across all editions — a stricter test than the per-edition one above,
// since this is about confirming a single canonical wording for G 18:202X).
const standardizeTerms = computed(() =>
  (harmonization as any[])
    .map(t => {
      const pubs = t.publications || [];
      const uniquePubIds = new Set(pubs.map((p: any) => p.publication_id));
      return {
        ...t,
        _defs: distinctDefsAll(pubs),
        _pubs: pubs.length,
        _uniquePubs: uniquePubIds.size,
      };
    })
    .filter(t => t._pubs >= 2 && t._defs === 1)
    .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
);

// Designation-collision analysis (same concept cited under multiple G 18 IDs)
const collisionEditions = computed(() => {
  const all = Object.keys((conflictsData as any).designation_collisions || {})
    .sort((a: string, b: string) => (b === "202X" ? 1 : 0) - (a === "202X" ? 1 : 0));
  if (editionFilter.value === "all") return all;
  return all.filter(e => e === editionFilter.value);
});
function collisionSummary(ed: string) {
  const list = ((conflictsData as any).designation_collisions || {})[ed] || [];
  const totalIds = list.reduce((s: number, c: any) => s + c.ids.length, 0);
  return {
    designations: list.length,
    totalIds,
    exactly2: list.filter((c: any) => c.ids.length === 2).length,
    ge3: list.filter((c: any) => c.ids.length >= 3).length,
    ge5: list.filter((c: any) => c.ids.length >= 5).length,
    ge10: list.filter((c: any) => c.ids.length >= 10).length,
  };
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Definition Conflicts</span></div>
    <h1>Definition conflicts</h1>
    <p class="lede">
      Terms cited by ≥ 2 OIML publications where <strong>a single edition has
      divergent definitions</strong>. Cross-edition wording changes (e.g. 2010 vs
      202X) are intentional editorial evolution and are excluded — TC 1
      harmonises WITHIN the 202X draft. Sort by divergence to find the worst
      offenders; open a term to see definitions grouped (identical wording
      collapsed) and decide: merge into one, or document why divergence is
      intentional.
    </p>
  </div>

  <!-- Sticky page-level edition filter — at top so users see scope immediately -->
  <div class="page-filter" role="region" aria-label="Edition filter">
    <span class="page-filter-label">Edition scope</span>
    <div class="page-filter-controls">
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
              @click="editionFilter = '202X'">
        <span class="page-filter-btn-title">202X</span>
        <span class="page-filter-btn-meta">{{ editionCounts["202X"] }} divergent terms · draft, TC 1 acts here</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
              @click="editionFilter = '2010'">
        <span class="page-filter-btn-title">2010</span>
        <span class="page-filter-btn-meta">{{ editionCounts["2010"] }} divergent terms · historic, read-only</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' }]"
              @click="editionFilter = 'all'">
        <span class="page-filter-btn-title">All</span>
        <span class="page-filter-btn-meta">divergent in either edition</span>
      </button>
    </div>
  </div>

  <!-- Subnav for quick jumping between sections -->
  <nav class="card" style="padding:0.5em 1em;display:flex;gap:0.8em;flex-wrap:wrap;font-size:0.9em">
    <a href="#collisions">Designation collisions</a>
    <a href="#worklist">Worklist</a>
    <a href="#how-to">How to use</a>
    <a href="#standardize">Ready to standardize</a>
  </nav>

  <!-- Designation collisions: structural view of the same problem -->
  <section id="collisions" class="card">
    <h2>Designation collisions <span class="muted">(same concept, multiple IDs)</span></h2>
    <p class="lede">
      The same term appears under multiple distinct G 18 IDs because each
      OIML publication that cites it gets its own entry. For each duplicated
      designation, TC 1 must decide whether to <strong>merge</strong> all
      instances into a single canonical definition, or <strong>keep separate</strong>
      and document why each publication uses a deliberately different definition.
    </p>

    <h3>Summary by edition</h3>
    <div class="table-wrap">
      <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th>Metric</th>
            <th v-for="ed in collisionEditions" :key="ed">{{ ed }}</th>
          </tr>
        </thead>
        <tbody>
          <tr><td>Designations with multiple IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).designations }}</td></tr>
          <tr><td>Total IDs participating in duplication</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).totalIds }}</td></tr>
          <tr><td>Designations with exactly 2 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).exactly2 }}</td></tr>
          <tr><td>Designations with ≥ 3 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).ge3 }}</td></tr>
          <tr><td>Designations with ≥ 5 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).ge5 }}</td></tr>
          <tr><td>Designations with ≥ 10 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).ge10 }}</td></tr>
        </tbody>
      </table>
    </div>
    </div>

    <h3>Top 30 most-duplicated designations per edition</h3>
    <div v-for="ed in collisionEditions" :key="ed">
      <h4>{{ ed }}</h4>
      <div class="table-wrap">
        <div class="table-scroll">
      <table>
          <thead><tr><th>Designation</th><th>VIM/VIML</th><th>Distinct IDs</th><th>Total pubs</th><th>IDs</th></tr></thead>
          <tbody>
            <tr v-for="c in (((conflictsData as any).designation_collisions || {})[ed] || []).slice(0, 30)" :key="c.designation">
              <td><SLink :to="`/terms/${slugify(c.designation)}/`">{{ c.designation }}</SLink></td>
              <td><span v-if="termKind(c.designation)" :class="['kind', `kind-${termKind(c.designation)}`]">{{ termKind(c.designation) === 'defined_in_vim' ? 'VIM' : termKind(c.designation) === 'defined_in_viml' ? 'VIML' : '—' }}</span><span v-else class="muted">—</span></td>
              <td class="num"><strong>{{ c.ids.length }}</strong></td>
              <td class="num">{{ c.count }}</td>
              <td><code>{{ c.ids.slice(0, 5).join(', ') }}{{ c.ids.length > 5 ? '…' : '' }}</code></td>
            </tr>
          </tbody>
        </table>
    </div>
      </div>
    </div>
  </section>

  <!-- Worklist with sort -->
  <section id="worklist" class="card">
      <h2>Worklist</h2>
      <form class="filter-form" @submit.prevent>
        <input v-model="search" type="search" placeholder="Search term…" aria-label="Search term" />
        <div class="sort-toggle" role="group" aria-label="Sort by">
          <button v-for="opt in [
            { val: 'divergence', label: 'Divergence' },
            { val: 'citations', label: 'Citations' },
            { val: 'name', label: 'A–Z' },
          ]" :key="opt.val"
            type="button"
            :class="['sort-btn', { 'sort-btn-active': sort === opt.val }]"
            @click="sort = opt.val as SortKey"
          >{{ opt.label }}</button>
        </div>
      </form>
    <p class="muted">{{ rows.length }} terms with within-edition divergence (of {{ (harmonization as any[]).length }} cited by ≥ 2 publications).</p>
    <div class="table-wrap">
      <div class="table-scroll">
      <table>
        <thead><tr><th>#</th><th>Term</th><th>VIM</th><th>Inst.</th><th>Distinct defs</th><th>TC/SCs responsible</th></tr></thead>
        <tbody>
          <tr v-for="(t, i) in pagination.visible.value" :key="t.slug" :class="{ 'row-historic': isHistoricTerm(t) }">
            <td class="num">{{ (pagination.page.value - 1) * pagination.pageSize.value + i + 1 }}</td>
            <td class="term-cell">
              <SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink>
              <span v-if="isHistoricTerm(t)" class="badge badge-historic" title="This term exists only in the 2010 edition. TC 1 cannot act — 2010 is historic.">2010 only</span>
            </td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td class="num">{{ t._pubs }}</td>
            <td class="num"><span class="divergence-count">{{ t._defs }}</span></td>
            <td class="muted" style="font-size:0.85em">{{ tcscList(t.publications) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    </div>
    <PaginationControls :pagination="pagination" noun="terms" />
  </section>

  <section id="how-to" class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-amber-soft);">
    <h2>How to use this worklist</h2>
    <ol>
      <li>Sort by <strong>Divergence</strong> to find terms with the most distinct definitions across publications — the highest-priority harmonisation targets.</li>
      <li>Open a term to see its definitions grouped (identical wording collapsed into one card) and decide: merge or document the divergence.</li>
      <li>Use the <strong>designation collisions</strong> table above to understand the structural scope: many terms exist under 5–28 different G 18 IDs across OIML publications.</li>
      <li>For numbering errors (one ID → two unrelated concepts), see <SLink to="/conflicts/">ID conflicts</SLink>.</li>
    </ol>
  </section>

  <!-- Ready to standardize -->
  <section id="standardize" v-if="standardizeTerms.length" class="card">
    <h2>Ready to standardize ({{ standardizeTerms.length }})</h2>
    <p class="lede">
      Terms cited by ≥ 2 publications (or the same publication across multiple
      editions) where <strong>all definitions are identical</strong>. No
      editorial work needed — TC 1 can batch-confirm these as canonical for
      G 18:202X.
    </p>
    <div class="table-scroll">
      <table>
        <thead><tr><th>Term</th><th>VIM</th><th>Unique pubs</th><th>Instances</th><th>TC/SCs</th></tr></thead>
        <tbody>
          <tr v-for="t in standardizeTerms" :key="t.slug">
            <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td class="num">{{ t._uniquePubs }}</td>
            <td class="num">{{ t._pubs }}</td>
            <td class="muted" style="font-size:0.85em">{{ tcscList(t.publications) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
