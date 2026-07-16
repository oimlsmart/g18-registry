<script setup lang="ts">
import { computed, ref } from "vue";
import publications from "@/data/pub-list.json";
import { slugifyPubId } from "@/composables/useSuggestedActions";
import SLink from "@/components/SLink.vue";

const search = ref("");
const lifecycleFilter = ref("");

const filtered = computed(() => {
  let pubs = publications as any[];
  if (lifecycleFilter.value) {
    pubs = pubs.filter(p => (p.lifecycle || "current") === lifecycleFilter.value);
  }
  if (search.value) {
    const q = search.value.toLowerCase();
    pubs = pubs.filter(p => (p.id || "").toLowerCase().includes(q));
  }
  return pubs;
});

function termCount(pub: any): number { return pub.term_count || 0; }

const lifecycleCounts = computed(() => {
  const c = { current: 0, retired: 0, withdrawn: 0 };
  for (const p of (publications as any[])) {
    const lc = p.lifecycle || "current";
    if (c[lc] !== undefined) c[lc]++;
  }
  return c;
});

function lifecycleBadge(lc: string): { label: string; cls: string } {
  if (lc === "withdrawn") return { label: "Withdrawn", cls: "lc-withdrawn" };
  if (lc === "retired") return { label: "Retired", cls: "lc-retired" };
  return { label: "Current", cls: "lc-current" };
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Publications</span></div>
    <h1>Publications</h1>
    <p class="lede">{{ (publications as any[]).length }} publications · {{ lifecycleCounts.current }} current · {{ lifecycleCounts.retired }} retired · {{ lifecycleCounts.withdrawn }} withdrawn</p>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search publication…" />
      <select v-model="lifecycleFilter">
        <option value="">All statuses</option>
        <option value="current">Current only</option>
        <option value="retired">Retired only</option>
        <option value="withdrawn">Withdrawn only</option>
      </select>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>
    <div class="table-scroll">
      <table>
      <thead><tr><th>Reference</th><th>Status</th><th>Year</th><th>TC/SC</th><th>Terms</th></tr></thead>
      <tbody>
        <tr v-for="p in filtered" :key="p.id">
          <td><SLink :to="`/publications/${slugifyPubId(p.id)}/`">{{ p.reference || p.id }}</SLink></td>
          <td><span :class="['lc-badge', lifecycleBadge(p.lifecycle || 'current').cls]">{{ lifecycleBadge(p.lifecycle || 'current').label }}</span></td>
          <td class="num">{{ (p.id || '').match(/(\d{4})/)?.[1] || "—" }}</td>
          <td><SLink v-if="p.tc_sc" :to="`/tc/${p.tc_sc.toLowerCase().replace('/', '-')}/`">{{ p.tc_sc }}</SLink><span v-else class="muted">—</span></td>
          <td class="num">{{ termCount(p) }}</td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>
</template>

<style scoped>
.lc-badge {
  display: inline-block;
  padding: 0.1em 0.5em;
  border-radius: 3px;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  border: 1px solid;
}
.lc-current { background: var(--status-ok-bg); color: var(--status-ok-text); border-color: var(--status-ok-border); }
.lc-retired { background: var(--color-rule-soft); color: var(--color-ink-muted); border-color: var(--color-rule); }
.lc-withdrawn { background: var(--status-error-bg); color: var(--status-error-text); border-color: var(--status-error-border); }
</style>
