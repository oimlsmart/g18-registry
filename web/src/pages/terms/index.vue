<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useRoute } from "vue-router";
import terms from "@/data/terms.json";
import { usePagination } from "@/composables/usePagination";

const route = useRoute();
const search = ref("");
// Edition filter — 3-button sticky pattern. URL `?only=` params from old
// dashboard links still work: "202X" / "2010" map directly; "202X-only" /
// "2010-only" map to the closest scope + a banner explaining the cross-
// edition filter that's active.
type EditionFilter = "202X" | "2010" | "all";
const initialOnly = (route.query.only as string) || "";
const editionFilter = ref<EditionFilter>(
  initialOnly === "2010" ? "2010" :
  initialOnly === "202X" || initialOnly === "202X-only" ? "202X" :
  initialOnly === "2010-only" ? "all" : "202X"
);
// Cross-edition filter (set by `?only=` URL params from dashboard links).
const crossEdition = ref<"added" | "removed" | null>(
  initialOnly === "202X-only" ? "added" :
  initialOnly === "2010-only" ? "removed" : null
);
watch(() => route.query.only, (val) => {
  const v = (val as string) || "";
  if (v === "202X" || v === "202X-only") editionFilter.value = "202X";
  else if (v === "2010") editionFilter.value = "2010";
  else if (v === "2010-only") editionFilter.value = "all";
  crossEdition.value =
    v === "202X-only" ? "added" :
    v === "2010-only" ? "removed" : null;
});

const onlyTC = ref("");
const onlyKind = ref("");
const sortKey = ref<"name" | "pubs" | "defs">("name");
const sortDir = ref<1 | -1>(1);

const allTCs = computed(() => {
  const set = new Set<string>();
  for (const t of terms as any[]) {
    for (const p of t.publications || []) {
      if (p.tc_sc?.trim()) set.add(p.tc_sc);
    }
  }
  return Array.from(set).sort();
});

function distinctDefs(pubs: any[]) {
  return new Set(pubs.map(p => (p.definition || "").replace(/\{\{[^,}]+,([^}]+)\}\}/g, "$1").trim()).filter(Boolean)).size;
}

const filtered = computed(() => {
  let t = terms as any[];
  // Edition scope (sticky filter)
  if (editionFilter.value !== "all") {
    t = t.filter(x => (x.editions_present || []).includes(editionFilter.value));
  }
  // Cross-edition overlay (?only=...-only from dashboard links)
  if (crossEdition.value === "added") {
    t = t.filter(x => (x.editions_present || []).includes("202X") && !(x.editions_present || []).includes("2010"));
  } else if (crossEdition.value === "removed") {
    t = t.filter(x => (x.editions_present || []).includes("2010") && !(x.editions_present || []).includes("202X"));
  }
  if (onlyTC.value) {
    t = t.filter(x => x.publications?.some((p: any) => p.tc_sc === onlyTC.value));
  }
  if (onlyKind.value) {
    t = t.filter(x => x.kind === onlyKind.value);
  }
  if (search.value) {
    const q = search.value.toLowerCase();
    t = t.filter(x => x.name?.toLowerCase().includes(q));
  }

  const sorters: Record<string, (a: any, b: any) => number> = {
    name: (a, b) => (a.name || "").localeCompare(b.name || ""),
    pubs: (a, b) => (b.publications?.length || 0) - (a.publications?.length || 0),
    defs: (a, b) => distinctDefs(b.publications || []) - distinctDefs(a.publications || []),
  };
  const dir = sortDir.value;
  return [...t].sort((a, b) => sorters[sortKey.value](a, b) * dir);
});

const pagination = usePagination(filtered, {
  pageSize: 50,
  dep: () => `${editionFilter.value}|${crossEdition.value}|${onlyTC.value}|${onlyKind.value}|${search.value}|${sortKey.value}|${sortDir.value}`,
});

function toggleSort(key: "name" | "pubs" | "defs") {
  if (sortKey.value === key) {
    sortDir.value = (sortDir.value === 1 ? -1 : 1) as 1 | -1;
  } else {
    sortKey.value = key;
    sortDir.value = 1;
  }
}

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
function tcCount(t: any): number { return t.publications?.filter((p: any) => p.tc_sc === onlyTC.value).length || 0; }
function symbolsOf(t: any): string[] {
  if (!t.designations) return [];
  return Array.from(new Set(t.designations.filter((d: any) => d.type === "symbol").map((d: any) => d.text as string)));
}
function admittedOf(t: any): string[] {
  if (!t.designations) return [];
  return t.designations.filter((d: any) => d.type === "expression" && d.status === "admitted").map((d: any) => d.text as string);
}

const pageTitle = computed(() => {
  if (crossEdition.value === "removed") return "Terms removed in 202X (2010 only)";
  if (crossEdition.value === "added") return "Terms added in 202X (not in 2010)";
  if (editionFilter.value === "2010") return "Terms in 2010";
  if (editionFilter.value === "202X") return "Terms in 202X";
  return "All terms";
});
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Terms</span></div>
    <h1>{{ pageTitle }}</h1>
    <p class="lede">{{ filtered.length }} of {{ terms.length }} terms, {{ (terms as any[]).reduce((s, t) => s + t.publications.length, 0) }} instances.</p>
  </div>

  <!-- Sticky page-level edition filter (3-button pattern, same as other pages) -->
  <div class="page-filter" role="region" aria-label="Edition filter">
    <span class="page-filter-label">Edition scope</span>
    <div class="page-filter-controls">
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' && !crossEdition }]"
              @click="editionFilter = '202X'; crossEdition = null">
        <span class="page-filter-btn-title">202X</span>
        <span class="page-filter-btn-meta">draft, TC 1 acts here</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' && !crossEdition }]"
              @click="editionFilter = '2010'; crossEdition = null">
        <span class="page-filter-btn-title">2010</span>
        <span class="page-filter-btn-meta">historic, read-only</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' && !crossEdition }]"
              @click="editionFilter = 'all'; crossEdition = null">
        <span class="page-filter-btn-title">All</span>
        <span class="page-filter-btn-meta">both editions</span>
      </button>
    </div>
  </div>

  <!-- Cross-edition banner: shown when ?only=202X-only or ?only=2010-only
       brings the user here from the dashboard "Terms added/removed" links. -->
  <div v-if="crossEdition" class="cross-edition-banner">
    <strong>{{ crossEdition === "added" ? "Added in 202X" : "Removed from 202X" }}.</strong>
    Showing terms {{ crossEdition === "added" ? "present in 202X but not in 2010" : "present in 2010 but not in 202X" }}.
    <button type="button" class="link-button" @click="crossEdition = null">Clear</button>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search…" />
      <select v-model="onlyKind">
        <option value="">All (VIM/VIML/other)</option>
        <option value="defined_in_vim">VIM only</option>
        <option value="defined_in_viml">VIML only</option>
        <option value="oiml_original">Neither (OIML-original)</option>
      </select>
      <select v-model="onlyTC">
        <option value="">All TC/SCs</option>
        <option v-for="tc in allTCs" :key="tc" :value="tc">{{ tc }}</option>
      </select>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>
    <div class="table-scroll table-only-desktop">
      <table>
      <thead>
        <tr>
          <th @click="toggleSort('name')" style="cursor:pointer">Term {{ sortKey === 'name' ? (sortDir === 1 ? '↑' : '↓') : '' }}</th>
          <th>Alt</th>
          <th>Sym</th>
          <th>VIM</th>
          <th>Ed.</th>
          <th @click="toggleSort('pubs')" style="cursor:pointer" class="num">Inst. {{ sortKey === 'pubs' ? (sortDir === 1 ? '↑' : '↓') : '' }}</th>
          <th v-if="onlyTC">TC pubs</th>
          <th @click="toggleSort('defs')" style="cursor:pointer" class="num">Defs {{ sortKey === 'defs' ? (sortDir === 1 ? '↑' : '↓') : '' }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="t in pagination.visible.value" :key="t.slug">
          <td class="term-cell"><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
          <td class="alt-cell">
            <span v-for="ad in admittedOf(t)" :key="ad" class="alt-term">{{ ad }}</span>
          </td>
          <td class="sym-cell">
            <DefText v-for="s in symbolsOf(t)" :key="s" :text="s" />
          </td>
          <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
          <td><span v-for="e in [...(t.editions_present || [])].sort((a:string,b:string) => (b==='202X'?1:0)-(a==='202X'?1:0))" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ e }}</span></td>
          <td class="num">{{ t.publications.length }}</td>
          <td v-if="onlyTC" class="num">{{ tcCount(t) }}</td>
          <td class="num">{{ distinctDefs(t.publications) }}</td>
        </tr>
      </tbody>
    </table>
    </div>

    <!-- Mobile card view: replaces the wide table on narrow screens so users
         don't need to scroll horizontally to see every column. -->
    <ul class="term-cards table-only-mobile">
      <li v-for="t in pagination.visible.value" :key="t.slug" class="term-card">
        <div class="term-card-head">
          <SLink :to="`/terms/${t.slug}/`" class="term-card-name"><DefText :text="t.name" /></SLink>
          <span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span>
        </div>
        <div v-if="admittedOf(t).length || symbolsOf(t).length" class="term-card-meta">
          <span v-if="admittedOf(t).length" class="term-card-alt">
            <span class="muted">alt:</span>
            <span v-for="ad in admittedOf(t)" :key="ad" class="alt-term">{{ ad }}</span>
          </span>
          <span v-if="symbolsOf(t).length" class="term-card-sym">
            <span class="muted">sym:</span>
            <DefText v-for="s in symbolsOf(t)" :key="s" :text="s" />
          </span>
        </div>
        <div class="term-card-stats">
          <span v-for="e in [...(t.editions_present || [])].sort((a:string,b:string) => (b==='202X'?1:0)-(a==='202X'?1:0))" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ e }}</span>
          <span class="term-card-stat"><strong>{{ t.publications.length }}</strong> inst.</span>
          <span v-if="onlyTC" class="term-card-stat"><strong>{{ tcCount(t) }}</strong> TC pubs</span>
          <span class="term-card-stat"><strong>{{ distinctDefs(t.publications) }}</strong> defs</span>
        </div>
      </li>
    </ul>
    <PaginationControls :pagination="pagination" noun="terms" />
  </section>
</template>
