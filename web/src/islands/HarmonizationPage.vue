<script setup lang="ts">
import { ref, computed } from "vue";
import harmonizationSlim from "@/data/harmonization-slim.json";
import SLink from "@/components/SLink.vue";
import { slugify } from "@/utils/term-utils";
import { editionDataName } from "@/utils/edition-utils";

type EditionFilter = "current" | "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("current");

const designationCollisions = (harmonizationSlim as any).designation_collisions || {};

const collisionEditions = computed(() => {
  const all = Object.keys(designationCollisions)
    .sort((a: string, b: string) => (b === "202X" ? 1 : 0) - (a === "202X" ? 1 : 0));
  if (editionFilter.value === "all") return all;
  const ed = editionDataName(editionFilter.value);
  return all.filter(e => e === ed);
});

function collisionSummary(ed: string) {
  const list = designationCollisions[ed] || [];
  const totalIds = list.reduce((s: number, c: any) => s + c.ids.length, 0);
  return {
    designations: list.length,
    totalIds,
    exactly2: list.filter((c: any) => c.ids.length === 2).length,
    ge3: list.filter((c: any) => c.ids.length >= 3).length,
    ge5: list.filter((c: any) => c.ids.length >= 5).length,
    ge10: list.filter((c: any) => c.ids.length >= 10).length,
  };
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Definition Conflicts</span></div>
    <h1>Definition conflicts</h1>
    <p class="lede">
      Terms cited by ≥ 2 OIML publications where <strong>a single edition has
      divergent definitions</strong>. Cross-edition wording changes (e.g. 2010 vs
      202X) are intentional editorial evolution and are excluded — TC 1
      harmonises WITHIN the 202X draft.
    </p>
  </div>

  <!-- Sticky page-level edition filter — at top so users see scope immediately -->
  <div class="page-filter" role="region" aria-label="G 18 edition filter">
    <span class="page-filter-label">G 18 edition</span>
    <div class="page-filter-controls">
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'current' }]"
              @click="editionFilter = 'current'">
        <span class="page-filter-btn-title">G 18:Current</span>
        <span class="page-filter-btn-meta">{{ collisionSummary('complete').designations }} designations · live set from all publications</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
              @click="editionFilter = '202X'">
        <span class="page-filter-btn-title">G 18:202X</span>
        <span class="page-filter-btn-meta">{{ collisionSummary('202X').designations }} designations · draft, TC 1 acts here</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
              @click="editionFilter = '2010'">
        <span class="page-filter-btn-title">G 18:2010</span>
        <span class="page-filter-btn-meta">{{ collisionSummary('2010').designations }} designations · historic, read-only</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' }]"
              @click="editionFilter = 'all'">
        <span class="page-filter-btn-title">All</span>
        <span class="page-filter-btn-meta">all editions</span>
      </button>
    </div>
  </div>

  <!-- Designation collisions: structural view of the same problem -->
  <section id="collisions" class="card">
    <h2>Designation collisions <span class="muted">(same concept, multiple IDs)</span></h2>
    <p class="lede">
      The same term appears under multiple distinct G 18 IDs because each
      OIML publication that cites it gets its own entry. For each duplicated
      designation, TC 1 must decide whether to <strong>merge</strong> all
      instances into a single canonical definition, or <strong>keep separate</strong>
      and document why each publication uses a deliberately different definition.
    </p>

    <h3>Summary by edition</h3>
    <div class="table-wrap">
      <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th>Metric</th>
            <th v-for="ed in collisionEditions" :key="ed">{{ ed }}</th>
          </tr>
        </thead>
        <tbody>
          <tr><td>Designations with multiple IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).designations }}</td></tr>
          <tr><td>Total IDs participating in duplication</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).totalIds }}</td></tr>
          <tr><td>Designations with exactly 2 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).exactly2 }}</td></tr>
          <tr><td>Designations with ≥ 3 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).ge3 }}</td></tr>
          <tr><td>Designations with ≥ 5 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).ge5 }}</td></tr>
          <tr><td>Designations with ≥ 10 IDs</td><td v-for="ed in collisionEditions" :key="ed" class="num">{{ collisionSummary(ed).ge10 }}</td></tr>
        </tbody>
      </table>
    </div>
    </div>

    <h3>Top 30 most-duplicated designations per edition</h3>
    <div v-for="ed in collisionEditions" :key="ed">
      <h4>{{ ed }}</h4>
      <div class="table-wrap">
        <div class="table-scroll">
      <table>
          <thead><tr><th>Designation</th><th>Distinct IDs</th><th>Total pubs</th><th>IDs</th></tr></thead>
          <tbody>
            <tr v-for="c in (designationCollisions[ed] || []).slice(0, 30)" :key="c.designation">
              <td><SLink :to="`/concepts/${slugify(c.designation)}/`">{{ c.designation }}</SLink></td>
              <td class="num"><strong>{{ c.ids.length }}</strong></td>
              <td class="num">{{ c.count }}</td>
              <td><code>{{ c.ids.slice(0, 5).join(', ') }}{{ c.ids.length > 5 ? '…' : '' }}</code></td>
            </tr>
          </tbody>
        </table>
    </div>
      </div>
    </div>
  </section>

  <section class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-amber-soft);">
    <h2>How to use this worklist</h2>
    <ol>
      <li>Use the <strong>designation collisions</strong> table to understand the structural scope: many terms exist under multiple G 18 IDs across OIML publications.</li>
      <li>Open a term to see its definitions grouped (identical wording collapsed into one card) and decide: merge or document the divergence.</li>
      <li>For numbering errors (one ID → two unrelated concepts), see <SLink to="/g18/conflicts/">ID conflicts</SLink>.</li>
    </ol>
  </section>
</template>
