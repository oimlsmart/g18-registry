<script setup lang="ts">
import { computed, ref } from "vue";
import termsData from "@/data/terms-slim.json";
import publicationsData from "@/data/publications.json";
import { usePagination } from "@/composables/usePagination";
import SLink from "@/components/SLink.vue";
import PaginationControls from "@/components/PaginationControls.vue";
import { kindLabel } from "@/utils/term-utils";

const terms = termsData as any[];
const pubs = publicationsData as any[];

const currentPids = new Set(pubs.filter(p => p.lifecycle === "current").map(p => p.id));
const retiredPids = new Set(pubs.filter(p => p.lifecycle !== "current").map(p => p.id));

// Missing: active in OIML (cited by ≥1 current pub) but NOT in G 18:202X
const missing = computed(() =>
  terms.filter(t => {
    const eds = t.editions_present || [];
    const pids = t.pub_ids || [];
    const hasCurrent = pids.some((pid: string) => currentPids.has(pid));
    return hasCurrent && !eds.includes("202X");
  }).sort((a, b) => (b.pub_count || 0) - (a.pub_count || 0))
);

// Stale: in G 18:202X but ONLY from retired/withdrawn pubs
const stale = computed(() =>
  terms.filter(t => {
    const eds = t.editions_present || [];
    const pids = t.pub_ids || [];
    const hasCurrent = pids.some((pid: string) => currentPids.has(pid));
    return eds.includes("202X") && !hasCurrent;
  }).sort((a, b) => (a.name || "").localeCompare(b.name || ""))
);

const activeTab = ref<"missing" | "stale">("missing");
const search = ref("");

const currentList = computed(() => {
  const list = activeTab.value === "missing" ? missing.value : stale.value;
  if (!search.value) return list;
  const q = search.value.toLowerCase();
  return list.filter(t => t.name?.toLowerCase().includes(q));
});

const pagination = usePagination(currentList, {
  pageSize: 50,
  dep: () => `${activeTab.value}|${search.value}`,
});
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/g18/editions/">G 18</SLink> / <span>Coverage gaps</span></div>
    <h1>G 18:202X coverage gaps</h1>
    <p class="lede">
      Concepts that need G 18 editorial attention: {{ missing.length }} active in OIML but missing
      from the 202X draft, {{ stale.length }} in the draft but only from retired publications.
    </p>
  </div>

  <!-- Tab toggle -->
  <div class="tab-toggle">
    <button type="button"
            :class="['tab-btn', { 'tab-btn-active': activeTab === 'missing' }]"
            @click="activeTab = 'missing'">
      Missing from 202X
      <span class="tab-count">{{ missing.length }}</span>
    </button>
    <button type="button"
            :class="['tab-btn', { 'tab-btn-active': activeTab === 'stale' }]"
            @click="activeTab = 'stale'">
      Stale in 202X
      <span class="tab-count">{{ stale.length }}</span>
    </button>
  </div>

  <section class="card">
    <div v-if="activeTab === 'missing'" class="admonition warn" style="margin-bottom:1em">
      <strong>{{ missing.length }} concepts</strong> are cited by current OIML publications but
      have not yet been added to G 18:202X. The G 18 team should review and add them.
    </div>
    <div v-else class="admonition warn" style="margin-bottom:1em">
      <strong>{{ stale.length }} concepts</strong> are in G 18:202X but are only cited by retired
      or withdrawn publications. The G 18 team should review and consider removing them.
    </div>

    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search concept…" />
      <span class="muted">{{ currentList.length }} shown</span>
    </form>

    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th>Concept</th>
            <th>Source</th>
            <th class="num">Pubs</th>
            <th>Editions</th>
            <th v-if="activeTab === 'missing'">Cited by (current)</th>
            <th v-else>Last cited by</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in pagination.visible.value" :key="t.slug">
            <td><SLink :to="`/concepts/${t.slug}/`">{{ t.name }}</SLink></td>
            <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
            <td class="num">{{ t.pub_count }}</td>
            <td><span v-for="e in (t.editions_present || [])" :key="e" class="edition-pill">{{ e }}</span></td>
            <td><span class="muted" style="font-size:0.82rem">{{ (t.pub_ids || []).slice(0,3).join(', ') }}{{ (t.pub_ids || []).length > 3 ? '…' : '' }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
    <PaginationControls :pagination="pagination" noun="concepts" />
  </section>
</template>

<style scoped>
.tab-toggle { display: flex; gap: 0.4em; margin-bottom: 1em; }
.tab-btn {
  padding: 0.4em 1em;
  font-size: 0.86rem;
  font-weight: 600;
  border: 1px solid var(--color-rule);
  border-radius: 4px;
  background: var(--color-paper);
  color: var(--color-ink-soft);
  cursor: pointer;
}
.tab-btn:hover { background: var(--color-accent-tint); }
.tab-btn-active { background: var(--color-accent); color: #fff; border-color: var(--color-accent); }
.tab-count {
  display: inline-block;
  font-family: var(--font-mono);
  font-size: 0.76rem;
  padding: 0.05em 0.35em;
  border-radius: 3px;
  background: rgba(0,0,0,0.1);
  margin-left: 0.3em;
}
.tab-btn-active .tab-count { background: rgba(255,255,255,0.2); }
</style>
