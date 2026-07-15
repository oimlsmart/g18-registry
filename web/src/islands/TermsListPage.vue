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
function editionLabel(e: string): string {
  if (e === "complete") return "Current";
  if (e === "202X-draft") return "Draft";
  return e;
}
function sortedEditions(eds: string[] | undefined): string[] {
  const order: Record<string, number> = { "complete": 0, "202X": 1, "202X-draft": 2, "2010": 3 };
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

// V1/V2/V3 candidacy badge derived from kind.
function vocabCandidate(t: any): { label: string; cls: string } | null {
  if (t.kind === "defined_in_viml") return { label: "V1", cls: "cand-v1" };
  if (t.kind === "defined_in_vim") return { label: "V2", cls: "cand-v2" };
  if (t.kind === "oiml_original") return { label: "V3", cls: "cand-v3" };
  return null;
}

// Action priority indicator: find the highest-priority action type.
const PRIORITY_ORDER: Record<string, number> = {
  harmonize: 0, upgrade_vim: 1, upgrade_viml: 2, removed: 3, adopt_vim: 4, adopt_viml: 5, standardize: 6, unique: 7,
};
function actionPriority(t: any): { label: string; cls: string } | null {
  const types = t.action_types || [];
  if (!types.length) return null;
  const sorted = [...types].sort((a, b) => (PRIORITY_ORDER[a] ?? 9) - (PRIORITY_ORDER[b] ?? 9));
  const top = sorted[0];
  if (top === "harmonize") return { label: "High", cls: "badge-ko" };
  if (["upgrade_vim", "upgrade_viml", "removed"].includes(top)) return { label: "Med", cls: "badge-partial" };
  return { label: "Info", cls: "badge-pending" };
}

const pageTitle = computed(() => "Concepts defined in OIML publications");
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Concepts</span></div>
    <h1>{{ pageTitle }}</h1>
    <p class="lede">{{ filtered.length }} concepts</p>
  </div>

  <!-- Edition overview: simple counts per edition -->
  <div class="edition-overview">
    <span class="edition-overview-total">{{ terms.length }} concepts</span>
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
          <th>G 18 #</th>
          <th>D</th>
          <th>V</th>
          <th>P</th>
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
          <td class="g18-id-cell">
            <span class="g18-id">{{ t.identifier || "—" }}</span>
            <span v-for="e in sortedEditions(t.editions_present)" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ editionLabel(e) }}</span>
          </td>
          <td>
            <span v-if="(t.distinct_def_count || 0) > 1" class="indicator indicator-multi-defs" :title="`${t.distinct_def_count} distinct definitions`">⚠</span>
          </td>
          <td>
            <span v-if="vocabCandidate(t)" :class="['cand-badge', vocabCandidate(t)!.cls]" :title="`Vocab candidacy: ${vocabCandidate(t)!.label}`">{{ vocabCandidate(t)!.label }}</span>
          </td>
          <td>
            <span v-if="actionPriority(t)" :class="['badge', actionPriority(t)!.cls]" :title="`Top action: ${(t.action_types || []).join(', ')}`">{{ actionPriority(t)!.label }}</span>
          </td>
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
          <span class="g18-id">{{ t.identifier || "—" }}</span>
          <span v-for="e in sortedEditions(t.editions_present)" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ editionLabel(e) }}</span>
          <span v-if="vocabCandidate(t)" :class="['cand-badge', vocabCandidate(t)!.cls]">{{ vocabCandidate(t)!.label }}</span>
          <span v-if="actionPriority(t)" :class="['badge', actionPriority(t)!.cls]">{{ actionPriority(t)!.label }}</span>
          <span class="term-card-stat"><strong>{{ t.pub_count }}</strong> inst.</span>
          <span v-if="onlyTC" class="term-card-stat"><strong>{{ tcCount(t) }}</strong> TC pubs</span>
          <span class="term-card-stat"><strong>{{ t.distinct_def_count }}</strong> defs</span>
        </div>
      </li>
    </ul>
    <PaginationControls :pagination="pagination" noun="terms" />
  </section>
</template>

<style scoped>
.g18-id-cell {
  display: flex;
  flex-direction: column;
  gap: 0.2em;
  align-items: flex-start;
}
.g18-id {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  color: var(--color-ink-muted);
  white-space: nowrap;
}
.indicator {
  display: inline-block;
  font-size: 0.9rem;
  line-height: 1;
}
.indicator-multi-defs {
  color: var(--status-warn-text, #b58900);
}
.cand-badge {
  display: inline-block;
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.1em 0.4em;
  border-radius: 3px;
  letter-spacing: 0.02em;
}
.cand-v1 {
  background: var(--status-ok-bg);
  color: var(--status-ok-text);
}
.cand-v2 {
  background: var(--status-info-bg);
  color: var(--status-info-text);
}
.cand-v3 {
  background: var(--color-accent-tint);
  color: var(--color-accent);
}
</style>
