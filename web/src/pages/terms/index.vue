<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useRoute } from "vue-router";
import terms from "@/data/terms.json";

const route = useRoute();
const search = ref("");
const onlyEdition = ref((route.query.only as string) || "");
const onlyTC = ref("");

watch(() => route.query.only, (val) => { onlyEdition.value = (val as string) || ""; });

// Build list of distinct TC/SCs from publication data
const allTCs = computed(() => {
  const set = new Set<string>();
  for (const t of terms as any[]) {
    for (const p of t.publications || []) {
      if (p.tc_sc?.trim()) set.add(p.tc_sc);
    }
  }
  return Array.from(set).sort();
});

const filtered = computed(() => {
  let t = terms as any[];
  if (onlyEdition.value === "2010-only") {
    // Deleted: in 2010 but NOT in 202X
    t = t.filter(x => (x.editions_present || []).includes("2010") && !(x.editions_present || []).includes("202X"));
  } else if (onlyEdition.value === "202X-only") {
    // Added: in 202X but NOT in 2010
    t = t.filter(x => (x.editions_present || []).includes("202X") && !(x.editions_present || []).includes("2010"));
  } else if (onlyEdition.value) {
    // Normal: all terms in this edition
    t = t.filter(x => x.editions_present?.includes(onlyEdition.value));
  }
  if (onlyTC.value) {
    t = t.filter(x => x.publications?.some((p: any) => p.tc_sc === onlyTC.value));
  }
  if (search.value) {
    const q = search.value.toLowerCase();
    t = t.filter(x => x.name?.toLowerCase().includes(q));
  }
  return t.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
});

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
function distinctDefs(pubs: any[]) { return new Set(pubs.map(p => (p.definition || "").trim()).filter(Boolean)).size; }
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
      <input v-model="search" type="search" placeholder="Search…" style="padding:0.3em 0.5em;min-width:16em;border:1px solid var(--rule);border-radius:3px" />
      <select v-model="onlyEdition">
        <option value="">All editions</option>
        <option value="2010">2010 (all)</option>
        <option value="202X">202X (all)</option>
        <option value="2010-only">Removed: in 2010 only (not in 202X)</option>
        <option value="202X-only">Added: in 202X only (not in 2010)</option>
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
          <th>Term</th>
          <th>Alt</th>
          <th>Sym</th>
          <th>VIM</th>
          <th>Ed.</th>
          <th>Inst.</th>
          <th v-if="onlyTC">TC pubs</th>
          <th>Distinct defs</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="t in filtered" :key="t.slug">
          <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
          <td class="alt-cell">
            <span v-for="ad in admittedOf(t)" :key="ad" class="alt-term">{{ ad }}</span>
          </td>
          <td class="sym-cell">
            <MathSymbol v-for="s in symbolsOf(t)" :key="s" :text="s" />
          </td>
          <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
          <td><span v-for="e in t.editions_present" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ e }}</span></td>
          <td class="num">{{ t.publications.length }}</td>
          <td v-if="onlyTC" class="num">{{ tcCount(t) }}</td>
          <td class="num">{{ distinctDefs(t.publications) }}</td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>
</template>
