<script setup lang="ts">
import { ref, computed } from "vue";
import harmonization from "@/data/harmonization.json";
import conflictsData from "@/data/conflicts.json";
import termsData from "@/data/terms.json";
import { usePagination } from "@/composables/usePagination";

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

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
function isHistoricTerm(t: any): boolean {
  const eds = t.editions_present || [];
  return eds.length > 0 && eds.every((e: string) => e === "2010");
}
function distinctDefs(pubs: any[]): number {
  // Max distinct definitions WITHIN A SINGLE EDITION. Cross-edition
  // definition changes (e.g. 2010 vs 202X wording differ) are intentional
  // editorial evolution and NOT a harmonisation conflict.
  const byEd: Record<string, Set<string>> = {};
  for (const p of pubs) {
    const d = (p.definition || "").trim();
    if (!d) continue;
    const ed = p.edition || "(unspecified)";
    if (!byEd[ed]) byEd[ed] = new Set();
    byEd[ed].add(d);
  }
  return Math.max(0, ...Object.values(byEd).map(s => s.size));
}
function distinctDefsAll(pubs: any[]): number {
  // Cross-edition count — used by the "Ready to standardize" check, where
  // we want to know if every pub (anywhere) uses identical wording.
  return new Set(pubs.map(p => (p.definition || "").trim()).filter(Boolean)).size;
}
function slugify(s: string) { return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }
function tcscList(pubs: any[]): string {
  const set = new Set(pubs.map(p => p.tc_sc).filter(Boolean));
  return Array.from(set).sort().join(", ");
}

const rows = computed(() => {
  let list = (harmonization as any[])
    .map(t => ({
      ...t,
      _defs: distinctDefs(t.publications),
      _pubs: t.publications.length,
    }))
    // Only show terms with WITHIN-EDITION divergence — these are the real
    // harmonisation conflicts. Cross-edition-only differences are intentional
    // editorial evolution, and identical-across-all-pubs is "ready to
    // standardize" (handled in its own section below).
    .filter(t => t._defs >= 2);
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

const pagination = usePagination(rows, {
  pageSize: 50,
  dep: () => `${sort.value}|${search.value}`,
});

const topDivergent = computed(() => [...rows.value].sort((a, b) => b._defs - a._defs || b._pubs - a._pubs).slice(0, 20));

// Terms ready to standardize: cited by ≥ 2 pubs, all definitions identical
// (across all editions — a stricter test than the per-edition one above,
// since this is about confirming a single canonical wording for G 18:202X).
const standardizeTerms = computed(() =>
  (harmonization as any[])
    .map(t => ({ ...t, _defs: distinctDefsAll(t.publications), _pubs: t.publications.length }))
    .filter(t => t._pubs >= 2 && t._defs === 1)
    .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
);

// Designation-collision analysis (same concept cited under multiple G 18 IDs)
const collisionEditions = Object.keys((conflictsData as any).designation_collisions || {}).sort((a: string, b: string) => (b === "202X" ? 1 : 0) - (a === "202X" ? 1 : 0));
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
    <PaginationControls :pagination="pagination" />
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

  <!-- Ready to standardize (TODO 6) -->
  <section id="standardize" v-if="standardizeTerms.length" class="card">
    <h2>Ready to standardize ({{ standardizeTerms.length }})</h2>
    <p class="lede">
      Terms cited by ≥ 2 publications where <strong>all definitions are identical</strong>.
      No editorial work needed — TC 1 can batch-confirm these as canonical for G 18:202X.
    </p>
    <div class="table-scroll">
      <table>
        <thead><tr><th>Term</th><th>VIM</th><th>Pubs</th><th>TC/SCs</th></tr></thead>
        <tbody>
          <tr v-for="t in standardizeTerms" :key="t.slug">
            <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td class="num">{{ t._pubs }}</td>
            <td class="muted" style="font-size:0.85em">{{ tcscList(t.publications) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
