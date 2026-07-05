<script setup lang="ts">
import { computed, ref } from "vue";
import termsData from "@/data/terms.json";
import { useSuggestedActions, ACTION_META, actionMeta } from "@/composables/useSuggestedActions";

const terms = termsData as any[];
const { byTerm, counts, allActions } = useSuggestedActions(terms);

const filterType = ref("");
const search = ref("");

const filtered = computed(() => {
  let groups = byTerm.value;
  if (filterType.value) {
    groups = groups
      .map(g => ({ ...g, actions: g.actions.filter(a => a.type === filterType.value) }))
      .filter(g => g.actions.length > 0);
  }
  if (search.value) {
    const q = search.value.toLowerCase();
    groups = groups.filter(g => g.name?.toLowerCase().includes(q));
  }
  return groups;
});

const totalActions = computed(() => allActions.value.length);
const totalTerms = computed(() => byTerm.value.length);

const priorityLabel = (rank: number) =>
  rank === 0 ? "High" : rank === 1 ? "Medium" : rank === 2 ? "Info" : "Low";

const priorityBadge = (rank: number) =>
  rank === 0 ? "badge-ko" : rank === 1 ? "badge-partial" : "badge-pending";

const filterButtons = computed(() => [
  { val: "", label: `All (${totalTerms.value})` },
  ...Object.entries(counts.value)
    .sort(([, a], [, b]) => b - a)
    .map(([type, count]) => ({ val: type, label: `${actionMeta(type).label} (${count})` })),
]);

// Show the legend above the table when filter is "All" or matches an action type
const legendTypes = computed(() => Object.keys(ACTION_META).filter(t => counts.value[t] > 0));
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Actions</span></div>
    <h1>Suggested actions for TC 1</h1>
    <p class="lede">{{ totalActions }} actions across {{ totalTerms }} terms, computed from citation currency, definition divergence, and vocabulary alignment.</p>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search term…" />
      <button v-for="b in filterButtons" :key="b.val"
        :class="['sort-btn', { 'sort-btn-active': filterType === b.val }]"
        @click.prevent="filterType = b.val"
      >{{ b.label }}</button>
    </form>

    <p class="muted" style="margin-top:0.6em;font-size:0.85rem">
      Showing {{ filtered.length }} terms · each row groups every action that applies to that term.
    </p>

    <!-- Action icon legend -->
    <div class="action-legend">
      <span class="action-legend-title">Legend:</span>
      <span v-for="t in legendTypes" :key="t" class="action-legend-item">
        <span class="action-icon" :class="`action-icon-${t}`">{{ actionMeta(t).icon }}</span>
        <span class="action-legend-label">{{ actionMeta(t).label }}</span>
      </span>
    </div>

    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th style="width:6em">Priority</th>
            <th>Term</th>
            <th>Actions needed</th>
            <th class="num">Affected pubs</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="g in filtered" :key="g.slug" :class="{ 'row-historic': g.isHistoric }">
            <td>
              <span class="badge" :class="priorityBadge(g.priorityRank)">{{ priorityLabel(g.priorityRank) }}</span>
            </td>
            <td class="term-cell">
              <SLink :to="`/terms/${g.slug}/`">{{ g.name }}</SLink>
              <span v-if="g.isHistoric" class="badge badge-historic" title="This term exists only in the 2010 edition. TC 1 cannot act — 2010 is historic.">2010 only</span>
            </td>
            <td>
              <ul class="action-group-list">
                <li v-for="a in g.actions" :key="a.type">
                  <span class="action-icon" :class="`action-icon-${a.type}`" :title="actionMeta(a.type).label">{{ actionMeta(a.type).icon }}</span>
                  <span class="action-group-text">
                    <strong>{{ actionMeta(a.type).label }}</strong> — {{ a.description }}
                  </span>
                </li>
              </ul>
            </td>
            <td class="num">{{ g.pubCount }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<style scoped>
.action-group-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.45em;
}
.action-group-list li {
  display: flex;
  align-items: baseline;
  gap: 0.6em;
  margin: 0;
}
.action-group-text {
  font-size: 0.92em;
  color: var(--color-ink-soft);
  line-height: 1.45;
}
@media (max-width: 720px) {
  .action-group-list li {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.2em;
  }
}
</style>
