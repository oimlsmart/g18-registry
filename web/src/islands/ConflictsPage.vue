<script setup lang="ts">
import { computed, ref } from "vue";
import { slugify } from "@/utils/term-utils";
import conflictsData from "@/data/conflicts.json";
import { slugifyPubId } from "@/composables/useSuggestedActions";
import SLink from "@/components/SLink.vue";

type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");

const rawByEditionAll = (conflictsData as any).raw || {};
const allEditions = Object.keys(rawByEditionAll).sort((a, b) =>
  (b === "202X" ? 1 : 0) - (a === "202X" ? 1 : 0)
);
// Editions shown in the current view (respecting the filter).
const editions = computed(() =>
  editionFilter.value === "all" ? allEditions : allEditions.filter(e => e === editionFilter.value)
);
const totalCount = computed(() =>
  editions.value.reduce((s, ed) => s + (rawByEditionAll[ed] || []).length, 0)
);

// Per-edition counts for the filter button meta text.
const editionCounts = computed(() => {
  const c: Record<string, number> = { "202X": 0, "2010": 0 };
  for (const ed of allEditions) c[ed] = (rawByEditionAll[ed] || []).length;
  return c;
});
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>ID Conflicts</span></div>
    <h1>ID conflicts in G 18</h1>
    <div class="admonition warn" style="margin:0.8em 0">
      <strong>TC 1 internal use.</strong> ID conflicts are numbering errors that TC 1
      must resolve by formally reallocating G 18 numbers in the 202X revision.
      Other audiences do not need to act on these.
    </div>
    <p class="lede">
      A single G 18 identifier assigned to two semantically <em>different</em> concepts.
      These are distinct from
      <SLink to="/analysis/designations/">definition conflicts</SLink>,
      where the <em>same</em> concept has divergent definitions across publications.
    </p>
  </div>

  <!-- Sticky page-level edition filter — same pattern as other registry pages -->
  <div class="page-filter" role="region" aria-label="G 18 edition filter">
    <span class="page-filter-label">G 18 edition</span>
    <div class="page-filter-controls">
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
              @click="editionFilter = '202X'">
        <span class="page-filter-btn-title">G 18:202X</span>
        <span class="page-filter-btn-meta">{{ editionCounts["202X"] }} conflicting IDs · draft, TC 1 acts here</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
              @click="editionFilter = '2010'">
        <span class="page-filter-btn-title">G 18:2010</span>
        <span class="page-filter-btn-meta">{{ editionCounts["2010"] }} conflicting IDs · historic, read-only</span>
      </button>
      <button type="button"
              :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' }]"
              @click="editionFilter = 'all'">
        <span class="page-filter-btn-title">All</span>
        <span class="page-filter-btn-meta">{{ allEditions.reduce((s, e) => s + editionCounts[e], 0) }} conflicting IDs · both editions</span>
      </button>
    </div>
  </div>

  <section class="card">
    <h2>What is an ID conflict?</h2>
    <p>
      An ID conflict occurs when the source publication reuses one G 18 number
      for two unrelated concepts — a numbering error, not a harmonisation
      issue. In the 2010 edition these were patched in the dataset with an
      <code>a</code>/<code>b</code> suffix split (e.g. <code>00474a</code>
      vs <code>00474b</code>); TC 1 should formally reallocate the numbers
      in the 202X revision.
    </p>
    <p v-if="!totalCount" class="muted">
      No ID conflicts detected in the selected edition. ✓
    </p>
  </section>

  <section v-for="ed in editions" :key="ed" class="card">
    <h2>{{ ed }} <span class="muted">({{ rawByEditionAll[ed].length }} conflicting IDs)</span></h2>
    <div class="table-scroll">
      <table>
      <thead><tr><th style="width:7em">ID</th><th>Distinct concepts sharing the ID</th></tr></thead>
      <tbody>
        <tr v-for="c in rawByEditionAll[ed]" :key="c.id">
          <td><code>{{ c.id }}</code></td>
          <td>
            <div v-for="con in c.concepts" :key="con.designation + con.source" class="conflict-concept">
              <SLink :to="`/concepts/${slugify(con.designation)}/`"><strong>{{ con.designation }}</strong></SLink>
              <span class="muted"> — <SLink v-if="con.source" :to="`/publications/${slugifyPubId(con.source)}/`">{{ con.source }}</SLink> <code>{{ con.raw_id }}</code></span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    </div>
  </section>

  <section class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-amber-soft);">
    <h2>How TC 1 should resolve these</h2>
    <ul>
      <li>For each conflicting ID, decide which concept keeps the number and assign a new G 18 ID to the other.</li>
      <li>Update the <code>identifier</code> field on the displaced concept in <code>oimlsmart/vocab datasets/g18-202X/</code>.</li>
      <li>The 2010 dataset uses the <code>&lt;id&gt;a</code>/<code>&lt;id&gt;b</code> suffix convention (e.g. <code>00474a</code> / <code>00474b</code>) to disambiguate.</li>
      <li>The 202X dataset uses a publication-derived suffix (<code>&lt;id&gt;-RXXX-N</code>, e.g. <code>02344-R049-1</code> / <code>02344-R099-1</code>) — the underlying G 18 number is still shared and needs editorial reallocation.</li>
      <li>Both styles are dataset workarounds, not published conventions.</li>
      <li>For the related problem of one concept cited under many IDs, see the <SLink to="/analysis/designations/">harmonisation worklist</SLink>.</li>
    </ul>
  </section>
</template>
