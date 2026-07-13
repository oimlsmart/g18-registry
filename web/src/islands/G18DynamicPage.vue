<script setup lang="ts">
import { computed, ref } from "vue";
import termsData from "@/data/g18-dynamic.json";
import SLink from "@/components/SLink.vue";
import PaginationControls from "@/components/PaginationControls.vue";
import { usePagination } from "@/composables/usePagination";
import { kindLabel } from "@/utils/term-utils";

const terms = termsData as any[];

function vocabBadge(kind: string): string {
  if (kind === "defined_in_vim") return "badge-ok";
  if (kind === "defined_in_viml") return "badge-partial";
  return "badge-pending";
}

const search = ref("");
const vocabFilter = ref("");

const filtered = computed(() => {
  let t = terms;
  if (vocabFilter.value) {
    t = t.filter(x => x.kind === vocabFilter.value);
  }
  if (search.value) {
    const q = search.value.toLowerCase();
    t = t.filter(x => x.name?.toLowerCase().includes(q));
  }
  return [...t].sort((a, b) => (a.name || "").localeCompare(b.name || ""));
});

const pagination = usePagination(filtered, {
  pageSize: 50,
  dep: () => `${search.value}|${vocabFilter.value}`,
});

// Coverage stats
const total = terms.length;
const fromVim = terms.filter(t => t.kind === "defined_in_vim").length;
const fromViml = terms.filter(t => t.kind === "defined_in_viml").length;
const oimlOriginal = terms.filter(t => t.kind === "oiml_original" || t.kind === "undefined").length;
const withDefinition = terms.filter(t => t.definition && t.definition.trim()).length;
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/g18/editions/">G 18</SLink> / <span>Dynamic</span></div>
    <h1>G 18:dynamic</h1>
    <p class="lede">
      A live document, auto-generated from the concept registry. Unlike the
      statically published editions, G 18:dynamic reflects the current state of
      harmonized terminology at all times — no manual compilation cycle.
    </p>
  </div>

  <div class="admonition" style="background: var(--status-info-bg); border-color: var(--status-info-border); color: var(--status-info-text); margin-bottom: 1.2em;">
    <strong>Vision:</strong> When developing a future SMART Recommendation, specification
    of a term in Part 1 would retrieve the agreed definition from the agreed vocabulary.
    G 18:dynamic makes this possible by maintaining a live concept registry.
  </div>

  <section class="grid grid-4">
    <div class="stat-card"><div class="stat-value">{{ total }}</div><div class="stat-label">total concepts</div></div>
    <div class="stat-card"><div class="stat-value">{{ withDefinition }}</div><div class="stat-label">with definitions</div></div>
    <div class="stat-card"><div class="stat-value">{{ fromVim + fromViml }}</div><div class="stat-label">from V 1/V 2</div></div>
    <div class="stat-card"><div class="stat-value">{{ oimlOriginal }}</div><div class="stat-label">OIML-specific (V 3)</div></div>
  </section>

  <section class="card">
    <div class="card-head">
      <h2>Concept registry</h2>
    </div>
    <form class="filter-form" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search concept…" />
      <select v-model="vocabFilter">
        <option value="">All vocabularies</option>
        <option value="defined_in_vim">V 2 (VIM)</option>
        <option value="defined_in_viml">V 1 (VIML)</option>
        <option value="oiml_original">V 3 candidates (OIML-specific)</option>
      </select>
      <span class="muted">{{ filtered.length }} shown</span>
    </form>

    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th>Concept</th>
            <th>Vocabulary</th>
            <th>Definition</th>
            <th class="num">Pubs</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in pagination.visible.value" :key="t.slug">
            <td><SLink :to="`/concepts/${t.slug}/`">{{ t.name }}</SLink></td>
            <td>
              <span :class="['badge', vocabBadge(t.kind)]">
                {{ kindLabel(t.kind) }}
              </span>
            </td>
            <td class="concept-def">
              <span class="muted" style="font-size:0.85em">{{ t.definition || "—" }}</span>
            </td>
            <td class="num">{{ t.pub_count }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <PaginationControls :pagination="pagination" noun="concepts" />
  </section>
</template>

<style scoped>
.concept-def { max-width: 400px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
