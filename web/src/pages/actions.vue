<script setup lang="ts">
import { computed, ref } from "vue";
import termsData from "@/data/terms.json";
import { useSuggestedActions } from "@/composables/useSuggestedActions";

const terms = termsData as any[];
const { byTerm, counts, allActions } = useSuggestedActions(terms);

const filterType = ref("");
const search = ref("");

const typeLabels: Record<string, string> = {
  upgrade_vim: "Upgrade VIM",
  upgrade_viml: "Upgrade VIML",
  removed: "Removed",
  harmonize: "Harmonize",
  standardize: "Standardize",
  unique: "Unique",
  adopt_vim: "Adopt VIM",
  adopt_viml: "Adopt VIML",
};

const priorityLabel = (rank: number) =>
  rank === 0 ? "High" : rank === 1 ? "Medium" : rank === 2 ? "Info" : "Low";

const priorityBadge = (rank: number) =>
  rank === 0 ? "badge-ko" : rank === 1 ? "badge-partial" : "badge-pending";

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

const filterButtons = computed(() => [
  { val: "", label: `All (${totalTerms.value})` },
  ...Object.entries(counts.value)
    .sort(([, a], [, b]) => b - a)
    .map(([type, count]) => ({ val: type, label: `${typeLabels[type] || type} (${count})` })),
]);
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
          <tr v-for="g in filtered" :key="g.slug">
            <td>
              <span class="badge" :class="priorityBadge(g.priorityRank)">{{ priorityLabel(g.priorityRank) }}</span>
            </td>
            <td><SLink :to="`/terms/${g.slug}/`">{{ g.name }}</SLink></td>
            <td>
              <ul class="action-group-list">
                <li v-for="a in g.actions" :key="a.type">
                  <span class="action-pill" :class="`action-pill-${a.priority}`">{{ typeLabels[a.type] || a.type }}</span>
                  <span class="action-group-text">{{ a.description }}</span>
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
