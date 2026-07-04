<script setup lang="ts">
import { ref, computed } from "vue";
import harmonization from "@/data/harmonization.json";
import conflictsData from "@/data/conflicts.json";

type SortKey = "divergence" | "citations" | "name";
const sort = ref<SortKey>("divergence");
const search = ref("");

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
function distinctDefs(pubs: any[]) { return new Set(pubs.map(p => (p.definition || "").trim()).filter(Boolean)).size; }
function slugify(s: string) { return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }

const rows = computed(() => {
  let list = (harmonization as any[])
    .map(t => ({
      ...t,
      _defs: distinctDefs(t.publications),
      _pubs: t.publications.length,
    }));
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

const topDivergent = computed(() => [...rows.value].sort((a, b) => b._defs - a._defs || b._pubs - a._pubs).slice(0, 20));

// Designation-collision analysis (same concept cited under multiple G 18 IDs)
const collisionEditions = Object.keys((conflictsData as any).designation_collisions || {}).sort();
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
      Terms cited by ≥ 2 OIML publications with <strong>divergent definitions</strong>.
      Each row shows the number of distinct definition texts across the publications
      that cite the term. Sort by divergence to find the worst offenders — these are
      TC 1's harmonisation targets. Open a term to see definitions grouped (identical
      wording collapsed) and decide: merge into one, or document why divergence is
      intentional.
    </p>
  </div>

  <!-- Designation collisions: structural view of the same problem -->
  <section class="card">
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

    <h3>Top 30 most-duplicated designations per edition</h3>
    <div v-for="ed in collisionEditions" :key="ed">
      <h4>{{ ed }}</h4>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Designation</th><th>Distinct IDs</th><th>Total pubs</th><th>IDs</th></tr></thead>
          <tbody>
            <tr v-for="c in (((conflictsData as any).designation_collisions || {})[ed] || []).slice(0, 30)" :key="c.designation">
              <td><SLink :to="`/terms/${slugify(c.designation)}/`">{{ c.designation }}</SLink></td>
              <td class="num"><strong>{{ c.ids.length }}</strong></td>
              <td class="num">{{ c.count }}</td>
              <td><code>{{ c.ids.slice(0, 5).join(', ') }}{{ c.ids.length > 5 ? '…' : '' }}</code></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </section>

  <!-- Worklist with sort -->
  <section class="card">
    <div class="card-head">
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
    </div>
    <p class="muted">{{ rows.length }} terms shown of {{ (harmonization as any[]).length }} cited by ≥ 2 publications.</p>
    <div class="table-wrap">
      <table>
        <thead><tr><th>#</th><th>Term</th><th>VIM</th><th>Inst.</th><th>Distinct defs</th></tr></thead>
        <tbody>
          <tr v-for="(t, i) in rows" :key="t.slug">
            <td class="num">{{ i + 1 }}</td>
            <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td class="num">{{ t._pubs }}</td>
            <td class="num"><span class="divergence-count">{{ t._defs }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <section class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-amber-soft);">
    <h2>How to use this worklist</h2>
    <ol>
      <li>Sort by <strong>Divergence</strong> to find terms with the most distinct definitions across publications — the highest-priority harmonisation targets.</li>
      <li>Open a term to see its definitions grouped (identical wording collapsed into one card) and decide: merge or document the divergence.</li>
      <li>Use the <strong>designation collisions</strong> table above to understand the structural scope: many terms exist under 5–28 different G 18 IDs across OIML publications.</li>
      <li>For numbering errors (one ID → two unrelated concepts), see <SLink to="/conflicts/">ID conflicts</SLink>.</li>
    </ol>
  </section>
</template>
