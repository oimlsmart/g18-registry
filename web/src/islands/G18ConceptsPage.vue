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
const onlyTC = ref("");
const onlyKind = ref("");
const sortKey = ref<"name" | "pubs" | "defs">("name");
const sortDir = ref<1 | -1>(1);

const allTCs = computed(() => {
  const set = new Set<string>();
  for (const t of terms) {
    for (const tc of (t.tc_scs || [])) set.add(tc);
  }
  return Array.from(set).sort();
});

const filtered = computed(() => {
  let t = terms;
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
  dep: () => `${onlyTC.value}|${onlyKind.value}|${search.value}|${sortKey.value}|${sortDir.value}`,
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
function sortedEditions(eds: string[] | undefined): string[] {
  const order: Record<string, number> = { "202X": 0, "2010": 1 };
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
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>G 18 concepts</span></div>
    <h1>G 18 concepts</h1>
    <p class="lede">{{ terms.length }} concepts · {{ filtered.length }} shown</p>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search…" />
      <select v-model="onlyKind">
        <option value="">All sources</option>
        <option value="defined_in_vim">From VIM (V 2)</option>
        <option value="defined_in_viml">From VIML (V 1)</option>
        <option value="oiml_original">OIML-specific</option>
      </select>
      <select v-model="onlyTC">
        <option value="">All TC/SCs</option>
        <option v-for="tc in allTCs" :key="tc" :value="tc">{{ tc }}</option>
      </select>
    </form>
    <div class="table-scroll table-only-desktop">
      <table>
      <thead>
        <tr>
          <th @click="toggleSort('name')" style="cursor:pointer">Term {{ sortKey === 'name' ? (sortDir === 1 ? '↑' : '↓') : '' }}</th>
          <th>Alt</th>
          <th>Sym</th>
          <th>Source</th>
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
          <td><span v-for="e in sortedEditions(t.editions_present)" :key="e" class="edition-pill">{{ e }}</span></td>
          <td class="num">{{ t.pub_count }}</td>
          <td v-if="onlyTC" class="num">{{ tcCount(t) }}</td>
          <td class="num">{{ t.distinct_def_count }}</td>
        </tr>
      </tbody>
    </table>
    </div>

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
        </div>
        <div class="term-card-stats">
          <span class="term-card-stat"><strong>{{ t.pub_count }}</strong> pubs</span>
          <span v-if="(t.distinct_def_count||0)>1" class="term-card-stat"><strong>{{ t.distinct_def_count }}</strong> defs</span>
        </div>
      </li>
    </ul>
    <PaginationControls :pagination="pagination" noun="concepts" />
  </section>
</template>

<style scoped>
.alt-cell { max-width: 200px; overflow: hidden; }
.alt-term { font-size: 0.82rem; color: var(--color-ink-muted); margin-right: 0.3em; }
.sym-cell { font-family: var(--font-mono); font-size: 0.85rem; white-space: nowrap; }
.term-cell { min-width: 180px; }
.term-card { padding: 0.6em 0.8em; border-bottom: 1px solid var(--color-rule-soft); }
.term-card-head { display: flex; justify-content: space-between; align-items: baseline; gap: 0.5em; }
.term-card-name { font-weight: 600; }
.term-card-meta { margin: 0.3em 0; font-size: 0.82rem; color: var(--color-ink-muted); }
.term-card-stats { display: flex; gap: 0.8em; font-size: 0.8rem; color: var(--color-ink-muted); }
.term-card-stat strong { color: var(--color-ink); }
</style>
