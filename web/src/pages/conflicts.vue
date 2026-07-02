<script setup lang="ts">
import conflictsData from "@/data/conflicts.json";

// Compute summary stats per edition from designation_collisions
const editions = Object.keys(conflictsData.designation_collisions || {}).sort();

function summary(ed: string) {
  const list = (conflictsData.designation_collisions as any)[ed] || [];
  const totalIds = list.reduce((s: number, c: any) => s + c.ids.length, 0);
  const withNplus = (n: number) => list.filter((c: any) => c.ids.length >= n).length;
  return {
    designations: list.length,
    totalIds,
    exactly2: list.filter((c: any) => c.ids.length === 2).length,
    ge3: withNplus(3),
    ge5: withNplus(5),
    ge10: withNplus(10),
  };
}
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>ID Conflicts</span></div>
    <h1>Duplicate & conflicting G 18 IDs</h1>
    <p class="lede">
      Two types of ID issues across editions:
      <strong>raw conflicts</strong> (one ID assigned to two different concepts —
      a numbering error in the source publication) and
      <strong>designation collisions</strong> (the same term cited under multiple
      distinct IDs — the harmonisation worklist for TC 1).
    </p>
  </div>

  <!-- Raw ID conflicts -->
  <section class="card">
    <h2>Raw ID conflicts (same ID for different concepts)</h2>
    <p class="lede">
      The source publication used the same G 18 number for two semantically
      different concepts. In 2010 these are resolved via the
      <code>&lt;id&gt;a</code>/<code>&lt;id&gt;b</code> split convention.
    </p>
    <p v-if="!Object.keys(conflictsData.raw || {}).length || !Object.values(conflictsData.raw || {}).flat().length" class="muted">
      No raw ID conflicts detected. ✓
    </p>
    <template v-else>
      <div v-for="(list, ed) in conflictsData.raw" :key="ed">
        <h3 v-if="list.length">{{ ed }} ({{ list.length }} conflicting IDs)</h3>
        <table v-if="list.length">
          <thead><tr><th>ID</th><th>Distinct concepts sharing the ID</th></tr></thead>
          <tbody>
            <tr v-for="c in list" :key="c.id">
              <td><code>{{ c.id }}</code></td>
              <td>
                <div v-for="con in c.concepts" :key="con.designation + con.source">
                  <strong>{{ con.designation }}</strong>
                  <span class="muted"> from {{ con.source }} ({{ con.raw_id }})</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </section>

  <!-- Designation collisions analysis -->
  <section class="card">
    <h2>Designation collisions (same concept, multiple IDs)</h2>
    <p class="lede">
      The same term name appears under multiple distinct G 18 IDs because each
      OIML publication that cites the term gets its own entry. TC 1 must decide
      which ID becomes canonical in the 202X harmonisation.
    </p>

    <!-- Summary table -->
    <h3>Summary by edition</h3>
    <table>
      <thead>
        <tr>
          <th>Metric</th>
          <th v-for="ed in editions" :key="ed">{{ ed }}</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Designations with multiple IDs</td>
          <td v-for="ed in editions" :key="ed" class="num">{{ summary(ed).designations }}</td>
        </tr>
        <tr>
          <td>Total IDs participating in duplication</td>
          <td v-for="ed in editions" :key="ed" class="num">{{ summary(ed).totalIds }}</td>
        </tr>
        <tr>
          <td>Designations with exactly 2 IDs</td>
          <td v-for="ed in editions" :key="ed" class="num">{{ summary(ed).exactly2 }}</td>
        </tr>
        <tr>
          <td>Designations with ≥ 3 IDs</td>
          <td v-for="ed in editions" :key="ed" class="num">{{ summary(ed).ge3 }}</td>
        </tr>
        <tr>
          <td>Designations with ≥ 5 IDs</td>
          <td v-for="ed in editions" :key="ed" class="num">{{ summary(ed).ge5 }}</td>
        </tr>
        <tr>
          <td>Designations with ≥ 10 IDs</td>
          <td v-for="ed in editions" :key="ed" class="num">{{ summary(ed).ge10 }}</td>
        </tr>
      </tbody>
    </table>
  </section>

  <!-- Top collisions per edition -->
  <section class="card">
    <h3>Top 30 most-duplicated designations per edition</h3>
    <div v-for="ed in editions" :key="ed">
      <h4>{{ ed }}</h4>
      <table>
        <thead><tr><th>Designation</th><th>Distinct IDs</th><th>Total pubs</th><th>IDs</th></tr></thead>
        <tbody>
          <tr v-for="c in ((conflictsData.designation_collisions as any)[ed] || []).slice(0, 30)" :key="c.designation">
            <td>
              <SLink :to="`/terms/${c.designation.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')}/`">{{ c.designation }}</SLink>
            </td>
            <td class="num"><strong>{{ c.ids.length }}</strong></td>
            <td class="num">{{ c.count }}</td>
            <td><code>{{ c.ids.slice(0, 5).join(', ') }}{{ c.ids.length > 5 ? '…' : '' }}</code></td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <section class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-amber-soft);">
    <h2>What this means for TC 1</h2>
    <ul>
      <li><strong>Raw conflicts</strong> (7 in 2010, 0 in 202X): numbering errors in the source publication — already resolved via a/b splits. 202X is clean.</li>
      <li><strong>Designation collisions</strong> (284 in 2010, 391 in 202X): the same term appears under many IDs because each OIML publication that cites it gets a separate G 18 entry. TC 1's harmonisation task is to decide, for each duplicated designation, whether to:
        <ul>
          <li><strong>Merge</strong>: collapse all instances into a single canonical definition in 202X.</li>
          <li><strong>Keep separate</strong>: document why each publication uses a deliberately different definition.</li>
        </ul>
      </li>
      <li>The <SLink to="/harmonization/">harmonisation worklist</SLink> shows every term with divergent definitions for side-by-side comparison.</li>
    </ul>
  </section>
</template>
