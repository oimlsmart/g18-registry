<script setup lang="ts">
import { ref, computed } from "vue";
import harmonizationSlim from "@/data/harmonization-slim.json";
import SLink from "@/components/SLink.vue";
import { slugify } from "@/utils/term-utils";

const designationCollisions = (harmonizationSlim as any).designation_collisions || {};

// Merge collisions across ALL editions into one list. The same designation
// may appear in both 2010 and 202X — deduplicate by name and merge IDs.
// G 18 IDs are chips, not the primary sorting axis.
const mergedCollisions = computed(() => {
  const byDesignation = new Map<string, { designation: string; ids: Set<string>; count: number }>();
  for (const [_edition, entries] of Object.entries(designationCollisions)) {
    for (const c of (entries as any[])) {
      const existing = byDesignation.get(c.designation);
      if (existing) {
        c.ids.forEach((id: string) => existing.ids.add(id));
        existing.count += c.count;
      } else {
        byDesignation.set(c.designation, {
          designation: c.designation,
          ids: new Set(c.ids),
          count: c.count,
        });
      }
    }
  }
  return Array.from(byDesignation.values())
    .map(c => ({
      designation: c.designation,
      ids: Array.from(c.ids).sort(),
      count: c.count,
    }))
    .sort((a, b) => b.ids.length - a.ids.length || b.count - a.count);
});

const search = ref("");
const filteredCollisions = computed(() => {
  if (!search.value) return mergedCollisions.value;
  const q = search.value.toLowerCase();
  return mergedCollisions.value.filter(c => c.designation.toLowerCase().includes(q));
});

const summary = computed(() => ({
  designations: mergedCollisions.value.length,
  totalIds: mergedCollisions.value.reduce((s, c) => s + c.ids.length, 0),
  exactly2: mergedCollisions.value.filter(c => c.ids.length === 2).length,
  ge3: mergedCollisions.value.filter(c => c.ids.length >= 3).length,
  ge5: mergedCollisions.value.filter(c => c.ids.length >= 5).length,
  ge10: mergedCollisions.value.filter(c => c.ids.length >= 10).length,
}));
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Definition Conflicts</span></div>
    <h1>Designation collisions</h1>
    <p class="lede">
      The same term appears under multiple distinct G 18 IDs because each
      OIML publication that cites it gets its own entry. For each duplicated
      designation, TC 1 must decide: <strong>merge</strong> all instances into a
      single canonical definition, or <strong>keep separate</strong> and document why.
    </p>
  </div>

  <section id="collisions" class="card">
    <h2>Summary</h2>
    <div class="collision-stats">
      <div class="stat"><strong>{{ summary.designations }}</strong> designations with multiple IDs</div>
      <div class="stat"><strong>{{ summary.totalIds }}</strong> total G 18 IDs</div>
      <div class="stat"><strong>{{ summary.exactly2 }}</strong> with exactly 2 IDs</div>
      <div class="stat"><strong>{{ summary.ge3 }}</strong> with ≥ 3 IDs</div>
      <div class="stat"><strong>{{ summary.ge5 }}</strong> with ≥ 5 IDs</div>
      <div class="stat"><strong>{{ summary.ge10 }}</strong> with ≥ 10 IDs</div>
    </div>

    <div class="card-head" style="margin-top:1.5em">
      <h2>All collisions (merged across editions)</h2>
      <input v-model="search" type="search" placeholder="Search designation…" />
    </div>

    <div class="table-wrap">
      <div class="table-scroll">
      <table>
        <thead><tr><th>Designation</th><th class="num">Distinct IDs</th><th class="num">Pubs</th><th>G 18 IDs</th></tr></thead>
        <tbody>
          <tr v-for="c in filteredCollisions" :key="c.designation">
            <td><SLink :to="`/concepts/${slugify(c.designation)}/`">{{ c.designation }}</SLink></td>
            <td class="num"><strong>{{ c.ids.length }}</strong></td>
            <td class="num">{{ c.count }}</td>
            <td>
              <span v-for="id in c.ids.slice(0, 8)" :key="id" class="g18-chip">{{ id }}</span>
              <span v-if="c.ids.length > 8" class="muted">+{{ c.ids.length - 8 }} more</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    </div>
  </section>

  <section class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-amber-soft);">
    <h2>How to use this worklist</h2>
    <ol>
      <li>Open a designation to see its definitions grouped (identical wording collapsed into one card) and decide: merge or document the divergence.</li>
      <li>For numbering errors (one ID → two unrelated concepts), see <SLink to="/g18/conflicts/">ID conflicts</SLink>.</li>
    </ol>
  </section>
</template>

<style scoped>
.collision-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0.6em;
  margin: 0.5em 0;
}
.stat {
  padding: 0.5em 0.8em;
  border-radius: 4px;
  background: var(--color-paper-tint);
  font-size: 0.86rem;
  color: var(--color-ink-soft);
}
.stat strong { font-size: 1.1rem; color: var(--color-ink); }
.g18-chip {
  display: inline-block;
  font-family: var(--font-mono);
  font-size: 0.7rem;
  padding: 0.05em 0.4em;
  border-radius: 3px;
  background: var(--color-rule-soft);
  color: var(--color-ink-muted);
  margin-right: 0.2em;
  margin-bottom: 0.2em;
}
</style>
