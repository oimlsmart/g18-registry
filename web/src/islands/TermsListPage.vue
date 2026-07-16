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
const onlyAlignment = ref("");
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
  if (onlyAlignment.value) {
    t = t.filter(x => (x.alignment_status || "none") === onlyAlignment.value);
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

function alignLabel(status: string | undefined): string {
  if (status === "aligned") return "Aligned";
  if (status === "diverges") return "Diverges";
  if (status === "fuzzy") return "Fuzzy";
  return "No match";
}

function tcCount(t: any): number { return t.tc_counts?.[onlyTC.value] || 0; }

// G18 entry number: only show numeric identifiers from G18 editions.
// Compound IDs like "r140-T.1.15" from oiml-complete are not G18 entries.
function g18Entry(t: any): string {
  const id = t.identifier;
  if (!id || !/^\d+$/.test(String(id))) return "";
  const eds = t.editions_present || [];
  if (eds.includes("2010")) return `2010: ${id}`;
  if (eds.includes("202X")) return `202X: ${id}`;
  return id;
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
  harmonize: 0, upgrade_vim: 1, upgrade_viml: 2, removed: 3, retire: 3, standardize: 6, unique: 7,
};
function actionPriority(t: any): { label: string; cls: string } | null {
  const types = t.action_types || [];
  if (!types.length) return null;
  const sorted = [...types].sort((a, b) => (PRIORITY_ORDER[a] ?? 9) - (PRIORITY_ORDER[b] ?? 9));
  const top = sorted[0];
  if (top === "harmonize") return { label: "High", cls: "badge-ko" };
  if (["upgrade_vim", "upgrade_viml", "removed", "retire"].includes(top)) return { label: "Med", cls: "badge-partial" };
  return { label: "Info", cls: "badge-pending" };
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Concepts</span></div>
    <h1>Concepts defined in OIML publications</h1>
    <p class="lede">{{ terms.length }} concepts · {{ filtered.length }} shown</p>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search concept…" />
      <select v-model="onlyKind">
        <option value="">All sources</option>
        <option value="defined_in_vim">From VIM (V 2)</option>
        <option value="defined_in_viml">From VIML (V 1)</option>
        <option value="oiml_original">OIML-specific</option>
      </select>
      <select v-model="onlyAlignment">
        <option value="">All alignment</option>
        <option value="aligned">Aligned</option>
        <option value="diverges">Definition diverges</option>
        <option value="fuzzy">Fuzzy match</option>
        <option value="none">No match (V3 candidates)</option>
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
          <th @click="toggleSort('name')" style="cursor:pointer">Concept {{ sortKey === 'name' ? (sortDir === 1 ? '↑' : '↓') : '' }}</th>
          <th>Source</th>
          <th>Alignment</th>
          <th>G 18 #</th>
          <th>Div</th>
          <th>Vocab</th>
          <th>Priority</th>
          <th @click="toggleSort('pubs')" style="cursor:pointer" class="num">Pubs {{ sortKey === 'pubs' ? (sortDir === 1 ? '↑' : '↓') : '' }}</th>
          <th v-if="onlyTC">TC</th>
          <th @click="toggleSort('defs')" style="cursor:pointer" class="num">Defs {{ sortKey === 'defs' ? (sortDir === 1 ? '↑' : '↓') : '' }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="t in pagination.visible.value" :key="t.slug">
          <td class="term-cell"><SLink :to="`/concepts/${t.slug}/`"><DefText :text="t.name" /></SLink></td>
          <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
          <td><span :class="['align-badge', `align-${t.alignment_status || 'none'}`]">{{ alignLabel(t.alignment_status) }}</span></td>
          <td class="g18-id">{{ g18Entry(t) || "—" }}</td>
          <td>
            <span v-if="(t.distinct_def_count || 0) > 1" class="div-warn" :title="`${t.distinct_def_count} distinct definitions`">{{ t.distinct_def_count }}</span>
            <span v-else class="muted">—</span>
          </td>
          <td>
            <span v-if="vocabCandidate(t)" :class="['cand-badge', vocabCandidate(t)!.cls]">{{ vocabCandidate(t)!.label }}</span>
            <span v-else class="muted">—</span>
          </td>
          <td>
            <span v-if="actionPriority(t)" :class="['badge', actionPriority(t)!.cls]" :title="`Top action: ${(t.action_types || []).join(', ')}`">{{ actionPriority(t)!.label }}</span>
            <span v-else class="muted">—</span>
          </td>
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
        <div class="term-card-stats">
          <span v-if="g18Entry(t)" class="g18-id">{{ g18Entry(t) }}</span>
          <span v-if="vocabCandidate(t)" :class="['cand-badge', vocabCandidate(t)!.cls]">{{ vocabCandidate(t)!.label }}</span>
          <span v-if="actionPriority(t)" :class="['badge', actionPriority(t)!.cls]">{{ actionPriority(t)!.label }}</span>
          <span class="term-card-stat"><strong>{{ t.pub_count }}</strong> pubs</span>
          <span v-if="(t.distinct_def_count||0)>1" class="div-warn">{{ t.distinct_def_count }} defs</span>
        </div>
      </li>
    </ul>
    <PaginationControls :pagination="pagination" noun="concepts" />
  </section>
</template>

<style scoped>
.g18-id {
  font-family: var(--font-mono);
  font-size: 0.76rem;
  color: var(--color-ink-muted);
  white-space: nowrap;
}
.div-warn {
  font-weight: 700;
  font-size: 0.82rem;
  color: var(--status-warn-text, #b58900);
}
.cand-badge {
  display: inline-block;
  font-size: 0.7rem;
  font-weight: 700;
  padding: 0.1em 0.45em;
  border-radius: 3px;
  letter-spacing: 0.02em;
}
.cand-v1 { background: var(--status-ok-bg); color: var(--status-ok-text); }
.cand-v2 { background: var(--status-info-bg); color: var(--status-info-text); }
.cand-v3 { background: var(--color-accent-tint); color: var(--color-accent); }
.align-badge {
  display: inline-block;
  font-size: 0.68rem;
  font-weight: 700;
  padding: 0.1em 0.4em;
  border-radius: 3px;
  letter-spacing: 0.02em;
}
.align-aligned { background: var(--status-ok-bg); color: var(--status-ok-text); }
.align-diverges { background: var(--status-warn-bg); color: var(--status-warn-text); }
.align-fuzzy { background: var(--status-info-bg); color: var(--status-info-text); }
.align-none { background: var(--color-rule-soft); color: var(--color-ink-muted); }
</style>
