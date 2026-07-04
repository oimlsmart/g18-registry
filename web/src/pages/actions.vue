<script setup lang="ts">
import { computed, ref } from "vue";
import termsData from "@/data/terms.json";
import { useSuggestedActions } from "@/composables/useSuggestedActions";

const terms = termsData as any[];
const { allActions, counts } = useSuggestedActions(terms);

const filterType = ref("");
const search = ref("");

const filtered = computed(() => {
  let a = allActions.value;
  if (filterType.value) a = a.filter(x => x.type === filterType.value);
  if (search.value) {
    const q = search.value.toLowerCase();
    a = a.filter(x => x.name?.toLowerCase().includes(q));
  }
  return a;
});

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

const totalCount = computed(() => allActions.value.length);

const filterButtons = computed(() => [
  { val: "", label: `All (${totalCount.value})` },
  ...Object.entries(counts.value)
    .sort(([, a], [, b]) => b - a)
    .map(([type, count]) => ({ val: type, label: `${typeLabels[type] || type} (${count})` })),
]);
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Actions</span></div>
    <h1>Suggested actions for TC 1</h1>
    <p class="lede">{{ totalCount }} actions across {{ terms.length }} terms, computed from citation currency, definition divergence, and vocabulary alignment.</p>
  </div>

  <section class="card">
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search term…" />
      <button v-for="b in filterButtons" :key="b.val"
        :class="['sort-btn', { 'sort-btn-active': filterType === b.val }]"
        @click.prevent="filterType = b.val"
      >{{ b.label }}</button>
    </form>

    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th>Action</th>
            <th>Priority</th>
            <th>Term</th>
            <th>Description</th>
            <th>Affected pubs</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(a, i) in filtered" :key="i">
            <td><span class="action-pill" :class="`action-pill-${a.priority}`">{{ typeLabels[a.type] || a.type }}</span></td>
            <td><span class="badge" :class="`badge-${a.priority === 'high' ? 'ko' : a.priority === 'medium' ? 'partial' : 'pending'}`">{{ a.priority }}</span></td>
            <td><SLink :to="`/terms/${a.slug}/`">{{ a.name }}</SLink></td>
            <td>{{ a.description }}</td>
            <td class="num">{{ (a.publication_ids || []).length }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
