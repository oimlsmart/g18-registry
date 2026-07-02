<script setup lang="ts">
import { computed } from "vue";
import termsData from "@/data/terms.json";
import editionStats from "@/data/edition-stats.json";
import conflictsData from "@/data/conflicts.json";

const terms = termsData as any[];
const totalInstances = terms.reduce((s: number, t: any) => s + t.publications.length, 0);

function distinctDefs(t: any): number {
  return new Set(t.publications.map((p: any) => (p.definition || "").trim()).filter(Boolean)).size;
}
function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }

// ── Priority worklist ───────────────────────────────────────────────────
type Action = { priority: string; term: string; slug: string; reason: string; count?: number; };

const priorityActions = computed<Action[]>(() => {
  const actions: Action[] = [];
  for (const t of terms) {
    const dd = distinctDefs(t);
    const lc = t.latest_check;
    // HIGH: cites superseded VIM AND not in latest edition
    if (lc && !lc.found) {
      actions.push({ priority: "high", term: t.name, slug: t.slug, reason: `Cites superseded edition, NOT in ${lc.latest_label}`, count: t.publications.length });
    }
    // HIGH: many divergent definitions
    if (dd >= 5) {
      actions.push({ priority: "high", term: t.name, slug: t.slug, reason: `${dd} distinct definitions`, count: dd });
    }
    // MEDIUM: moderate divergence
    else if (dd >= 3) {
      actions.push({ priority: "medium", term: t.name, slug: t.slug, reason: `${dd} distinct definitions`, count: dd });
    }
    // INFO: high harmonisation value
    if (t.publications.length >= 10 && dd < 3) {
      actions.push({ priority: "info", term: t.name, slug: t.slug, reason: `Cited by ${t.publications.length} publications` });
    }
  }
  const order: Record<string, number> = { high: 0, medium: 1, info: 2, low: 3 };
  return actions.sort((a, b) => {
    const po = (order[a.priority] ?? 9) - (order[b.priority] ?? 9);
    if (po !== 0) return po;
    return (b.count || 0) - (a.count || 0);
  }).slice(0, 15);
});

const divergentCount = terms.filter(t => distinctDefs(t) > 1).length;
const okCount = terms.reduce((s: number, t: any) => s + t.publications.filter((p: any) => p.consistency === "ok").length, 0);
const rawConflictCount = Object.values(conflictsData.raw || {}).flat().length;
const collisionCount = Object.values(conflictsData.designation_collisions || {}).flat().length;

// ── Top divergent (proper numeric sort, NOT array comparison) ───────────
const topDivergent = computed(() =>
  terms
    .map(t => ({ ...t, _dd: distinctDefs(t) }))
    .filter(t => t._dd > 1)
    .sort((a, b) => {
      if (b._dd !== a._dd) return b._dd - a._dd;
      if (b.publications.length !== a.publications.length) return b.publications.length - a.publications.length;
      return (a.name || "").localeCompare(b.name || "");
    })
    .slice(0, 10)
);
</script>

<template>
  <div class="page-head">
    <h1>G 18 — OIML Term-Usage Registry</h1>
    <p class="lede">Dashboard for <strong>TC 1 / Vocabularies</strong> validating <a href="https://github.com/oimlsmart/vocab/tree/main/datasets/g18-202X">OIML G 18:202X</a>.</p>
  </div>

  <!-- Getting started guide for TC 1 -->
  <section class="card" style="background: var(--oiml-cream-soft); border-color: var(--oiml-brand-200);">
    <h2 style="color: var(--oiml-brand-700);">How to use this registry</h2>
    <ol style="margin: 0; padding-left: 1.4em; line-height: 1.7;">
      <li><strong>Review priority actions below</strong> — terms needing immediate attention (outdated VIM refs, divergent definitions).</li>
      <li><strong>Open the <SLink to="/harmonization/">harmonisation worklist</SLink></strong> — every term cited by multiple OIML publications, sorted by divergence.</li>
      <li><strong>For each term</strong>, review the grouped definitions (identical wording is collapsed) and decide: merge into one definition, or document why divergence is intentional.</li>
      <li><strong>Check the latest edition</strong> — the registry automatically verifies whether each term still exists in VIM 2012 / VIML 2022.</li>
      <li><strong>Filter by your TC/SC</strong> on the <SLink to="/terms/">terms page</SLink> to review only the publications your committee is responsible for.</li>
      <li><strong>Submit changes</strong> to <a href="https://github.com/oimlsmart/vocab/tree/main/datasets/g18-202X"><code>oimlsmart/vocab datasets/g18-202X/</code></a>.</li>
    </ol>
  </section>

  <section class="grid grid-4">
    <SLink class="stat-card" to="/terms/"><div class="stat-value">{{ terms.length }}</div><div class="stat-label">unique terms</div></SLink>
    <SLink class="stat-card" to="/harmonization/"><div class="stat-value">{{ divergentCount }}</div><div class="stat-label">divergent terms</div></SLink>
    <SLink class="stat-card" to="/editions/"><div class="stat-value">{{ okCount }}/{{ totalInstances }}</div><div class="stat-label">consistent</div></SLink>
    <SLink class="stat-card" to="/conflicts/"><div class="stat-value">{{ rawConflictCount }}</div><div class="stat-label">raw ID conflicts</div></SLink>
  </section>

  <section class="card">
    <h2>Priority actions for TC 1</h2>
    <p class="lede">Top 15 items needing attention, sorted by urgency.</p>
    <table>
      <thead><tr><th style="width:5em">Priority</th><th>Term</th><th>Issue</th><th>Impact</th><th></th></tr></thead>
      <tbody>
        <tr v-for="(a, i) in priorityActions" :key="i">
          <td><span :class="['action-pill', `action-pill-${a.priority}`]">{{ a.priority.toUpperCase() }}</span></td>
          <td><SLink :to="`/terms/${a.slug}/`">{{ a.term }}</SLink></td>
          <td>{{ a.reason }}</td>
          <td class="num">{{ a.count || '' }}</td>
          <td><SLink :to="`/terms/${a.slug}/`">Open →</SLink></td>
        </tr>
      </tbody>
    </table>
  </section>

  <section class="card">
    <div class="card-head">
      <h2>Most divergent terms</h2>
      <SLink to="/harmonization/" class="muted">Full worklist →</SLink>
    </div>
    <table>
      <thead><tr><th>#</th><th>Term</th><th>VIM</th><th>Ed.</th><th>Inst.</th><th>Distinct</th></tr></thead>
      <tbody>
        <tr v-for="(t, i) in topDivergent" :key="t.slug">
          <td class="num">{{ i + 1 }}</td>
          <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
          <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
          <td><span v-for="e in t.editions_present" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ e }}</span></td>
          <td class="num">{{ t.publications.length }}</td>
          <td class="num"><span class="divergence-count">{{ t._dd }}</span></td>
        </tr>
      </tbody>
    </table>
  </section>

  <section class="card">
    <h2>Edition comparison</h2>
    <table>
      <thead><tr><th>Edition</th><th>Concepts</th><th>Terms</th><th>Only here</th><th>Harmonise</th></tr></thead>
      <tbody>
        <tr v-for="s in editionStats.stats" :key="s.edition">
          <td><strong>{{ s.edition }}</strong> <span v-if="s.primary" class="match-status match-status-full">primary</span></td>
          <td class="num">{{ s.instances }}</td><td class="num">{{ s.terms }}</td>
          <td class="num">{{ s.only_in_edition }}</td><td class="num">{{ s.harmonization_candidates }}</td>
        </tr>
      </tbody>
    </table>
    <p style="margin-top:0.7em"><SLink to="/editions/">Full comparison →</SLink></p>
  </section>

  <section class="card">
    <h2>ID conflicts summary</h2>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:1em">
      <div><strong>Raw ID conflicts</strong> (same ID → different concepts)<br /><span class="stat-value">{{ rawConflictCount }}</span></div>
      <div><strong>Designation collisions</strong> (same concept → multiple IDs)<br /><span class="stat-value">{{ collisionCount }}</span></div>
    </div>
    <p style="margin-top:0.7em"><SLink to="/conflicts/">Full analysis →</SLink></p>
  </section>
</template>
