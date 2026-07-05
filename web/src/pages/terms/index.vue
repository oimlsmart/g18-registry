<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useRoute } from "vue-router";
import terms from "@/data/terms.json";
import { usePagination } from "@/composables/usePagination";

const route = useRoute();
const search = ref("");
const onlyEdition = ref((route.query.only as string) || "");
const onlyTC = ref("");
const onlyKind = ref("");
const sortKey = ref<"name" | "pubs" | "defs">("name");
const sortDir = ref<1 | -1>(1);

watch(() => route.query.only, (val) => { onlyEdition.value = (val as string) || ""; });

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
  if (onlyEdition.value === "2010-only") {
    t = t.filter(x => (x.editions_present || []).includes("2010") && !(x.editions_present || []).includes("202X"));
  } else if (onlyEdition.value === "202X-only") {
    t = t.filter(x => (x.editions_present || []).includes("202X") && !(x.editions_present || []).includes("2010"));
  } else if (onlyEdition.value) {
    t = t.filter(x => x.editions_present?.includes(onlyEdition.value));
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
  dep: () => `${onlyEdition.value}|${onlyTC.value}|${onlyKind.value}|${search.value}|${sortKey.value}|${sortDir.value}`,
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
  if (onlyEdition.value === "2010-only") return "Terms removed in 202X (2010 only)";
  if (onlyEdition.value === "202X-only") return "Terms added in 202X (not in 2010)";
  if (onlyEdition.value === "2010") return "Terms in 2010";
  if (onlyEdition.value === "202X") return "Terms in 202X";
  return "All terms";
});
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Terms</span></div>
    <h1>{{ pageTitle }}</h1>
    <p class="lede">{{ filtered.length }} of {{ terms.length }} terms, {{ (terms as any[]).reduce((s, t) => s + t.publications.length, 0) }} instances.</p>
  </div>
  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search…" />
      <select v-model="onlyKind">
        <option value="">All (VIM/VIML/other)</option>
        <option value="defined_in_vim">VIM only</option>
        <option value="defined_in_viml">VIML only</option>
        <option value="undefined">Neither (OIML-original)</option>
      </select>
      <select v-model="onlyEdition">
        <option value="">All editions</option>
        <option value="202X">202X (draft)</option>
        <option value="2010">2010 (historic)</option>
        <option value="202X-only">Added: 202X only</option>
        <option value="2010-only">Removed: 2010 only</option>
      </select>
      <select v-model="onlyTC">
        <option value="">All TC/SCs</option>
        <option v-for="tc in allTCs" :key="tc" :value="tc">{{ tc }}</option>
      </select>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>
    <div class="table-scroll">
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
    <PaginationControls :pagination="pagination" />
  </section>
</template>
