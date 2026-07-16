<script setup lang="ts">
import { ref, computed } from "vue";
import termsData from "@/data/terms-slim.json";
import { usePagination } from "@/composables/usePagination";
import SLink from "@/components/SLink.vue";
import DefText from "@/components/DefText.vue";
import PaginationControls from "@/components/PaginationControls.vue";
import { kindLabel } from "@/utils/term-utils";

const terms = termsData as any[];

const search = ref("");
// Edition filter — 3-button sticky pattern. URL `?only=` params from old
// dashboard links still work: "202X" / "2010" map directly; "202X-only" /
// "2010-only" map to the closest scope + a banner explaining the cross-
// edition filter that's active.
type EditionFilter = "current" | "202X" | "2010" | "all";
const urlParams = new URLSearchParams(typeof window !== "undefined" ? window.location.search : "");
const initialOnly = urlParams.get("only") || "";
const editionFilter = ref<EditionFilter>(
  initialOnly === "2010" ? "2010" :
  initialOnly === "202X" || initialOnly === "202X-only" ? "202X" :
  initialOnly === "2010-only" ? "all" : "current"
);
// Cross-edition filter (set by `?only=` URL params from dashboard links).
const crossEdition = ref<"added" | "removed" | null>(
  initialOnly === "202X-only" ? "added" :
  initialOnly === "2010-only" ? "removed" : null
);

const onlyTC = ref("");
const onlyKind = ref("");
const sortKey = ref<"name" | "pubs" | "defs">("name");
const sortDir = ref<1 | -1>(1);

const termsInCurrent = computed(() => (terms as any[]).filter(t => (t.editions_present || []).includes("complete")).length);
const termsIn202X = computed(() => (terms as any[]).filter(t => (t.editions_present || []).includes("202X")).length);
const termsIn2010 = computed(() => (terms as any[]).filter(t => (t.editions_present || []).includes("2010")).length);

const allTCs = computed(() => {
  const set = new Set<string>();
  for (const t of terms) {
    for (const tc of (t.tc_scs || [])) set.add(tc);
  }
  return Array.from(set).sort();
});

const filtered = computed(() => {
  let t = terms;
  if (editionFilter.value !== "all") {
    const ed = editionFilter.value === "current" ? "complete" : editionFilter.value;
    t = t.filter(x => (x.editions_present || []).includes(ed));
  }
  if (crossEdition.value === "added") {
    t = t.filter(x => (x.editions_present || []).includes("202X") && !(x.editions_present || []).includes("2010"));
  } else if (crossEdition.value === "removed") {
    t = t.filter(x => (x.editions_present || []).includes("2010") && !(x.editions_present || []).includes("202X"));
  }
  if (onlyTC.value) {
    t = t.filter(x => (x.tc_scs || []).includes(onlyTC.value));
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
    pubs: (a, b) => (b.pub_count || 0) - (a.pub_count || 0),
    defs: (a, b) => (b.distinct_def_count || 0) - (a.distinct_def_count || 0),
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

function tcCount(t: any): number { return t.tc_counts?.[onlyTC.value] || 0; }
function editionLabel(e: string): string {
  if (e === "complete") return "OIML";
  return e;
}
function sortedEditions(eds: string[] | undefined): string[] {
  const order: Record<string, number> = { "complete": 0, "202X": 1, "2010": 2 };
  return [...(eds || [])].sort((a, b) => (order[a] ?? 9) - (order[b] ?? 9));
}
function symbolsOf(t: any): string[] {
  if (!t.designations) return [];
  return Array.from(new Set(t.designations.filter((d: any) => d.type === "symbol").map((d: any) => d.text as string)));
}
function admittedOf(t: any): string[] {
  if (!t.designations) return [];
  return t.designations.filter((d: any) => d.type === "expression" && d.status === "admitted").map((d: any) => d.text as string);
}

const pageTitle = computed(() => {
  if (crossEdition.value === "removed") return "Concepts removed in G 18:202X (2010 only)";
  if (crossEdition.value === "added") return "Concepts added in G 18:202X (not in 2010)";
  if (editionFilter.value === "2010") return "Concepts in G 18:2010";
  if (editionFilter.value === "202X") return "Concepts in G 18:202X";
  if (editionFilter.value === "current") return "Concepts in G 18:Current";
  return "Concepts defined in OIML publications";
});
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>G 18 concepts</span></div>
    <h1>{{ pageTitle }}</h1>
    <p class="lede">{{ filtered.length }} concepts</p>
  </div>

  <!-- Edition overview: simple counts per edition -->
  <div class="edition-overview">
    <span class="edition-overview-total">{{ terms.length }} concepts total</span>
    <span class="edition-overview-detail">
      <strong>{{ termsInCurrent }}</strong> in G 18:Current · <strong>{{ termsIn202X }}</strong> in G 18:202X · <strong>{{ termsIn2010 }}</strong> in G 18:2010
    </span>
  </div>

  <!-- Sticky page-level edition filter — clean controls, no numbers -->
  <div class="page-filter" role="region" aria-label="G 18 edition filter">
    <span class="page-filter-label">G 18 edition</span>
    <div class="page-filter-controls">
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'current' && !crossEdition }]"
              @click="editionFilter = 'current'; crossEdition = null">
        <span class="page-filter-btn-title">G 18:Current</span>
        <span class="page-filter-btn-meta">live set from all publications</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' && !crossEdition }]"
              @click="editionFilter = '202X'; crossEdition = null">
        <span class="page-filter-btn-title">G 18:202X</span>
        <span class="page-filter-btn-meta">draft · TC 1 acts here</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' && !crossEdition }]"
              @click="editionFilter = '2010'; crossEdition = null">
        <span class="page-filter-btn-title">G 18:2010</span>
        <span class="page-filter-btn-meta">published · read-only</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' && !crossEdition }]"
              @click="editionFilter = 'all'; crossEdition = null">
        <span class="page-filter-btn-title">All</span>
        <span class="page-filter-btn-meta">all editions</span>
      </button>
    </div>
  </div>

  <!-- Cross-edition comparison: terms added/removed between editions.
       Reachable from /g18/editions/ links (?only=202X-only / 2010-only)
       OR directly from this page. On a static site the URL param is
       read client-side by Vue Router on initial load and on navigation. -->
  <div class="cross-edition-filter">
    <span class="cross-edition-label">Cross-edition:</span>
    <button type="button"
            :class="['sort-btn', { 'sort-btn-active': crossEdition === 'added' }]"
            @click="crossEdition = crossEdition === 'added' ? null : 'added'; editionFilter = '202X'">
      Added in 202X
    </button>
    <button type="button"
            :class="['sort-btn', { 'sort-btn-active': crossEdition === 'removed' }]"
            @click="crossEdition = crossEdition === 'removed' ? null : 'removed'; editionFilter = 'all'">
      Removed from 202X
    </button>
    <button v-if="crossEdition" type="button" class="sort-btn" @click="crossEdition = null">
      Clear
    </button>
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
          <td class="term-cell"><SLink :to="`/concepts/${t.slug}/`"><DefText :text="t.name" /></SLink></td>
          <td class="alt-cell">
            <span v-for="ad in admittedOf(t)" :key="ad" class="alt-term">{{ ad }}</span>
          </td>
          <td class="sym-cell">
            <DefText v-for="s in symbolsOf(t)" :key="s" :text="s" />
          </td>
          <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
          <td><span v-for="e in sortedEditions(t.editions_present)" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ editionLabel(e) }}</span></td>
          <td class="num">{{ t.pub_count }}</td>
          <td v-if="onlyTC" class="num">{{ tcCount(t) }}</td>
          <td class="num">{{ t.distinct_def_count }}</td>
        </tr>
      </tbody>
    </table>
    </div>

    <!-- Mobile card view: replaces the wide table on narrow screens so users
         don't need to scroll horizontally to see every column. -->
    <ul class="term-cards table-only-mobile">
      <li v-for="t in pagination.visible.value" :key="t.slug" class="term-card">
        <div class="term-card-head">
          <SLink :to="`/concepts/${t.slug}/`" class="term-card-name"><DefText :text="t.name" /></SLink>
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
          <span v-for="e in sortedEditions(t.editions_present)" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ editionLabel(e) }}</span>
          <span class="term-card-stat"><strong>{{ t.pub_count }}</strong> inst.</span>
          <span v-if="onlyTC" class="term-card-stat"><strong>{{ tcCount(t) }}</strong> TC pubs</span>
          <span class="term-card-stat"><strong>{{ t.distinct_def_count }}</strong> defs</span>
        </div>
      </li>
    </ul>
    <PaginationControls :pagination="pagination" noun="terms" />
  </section>
</template>
