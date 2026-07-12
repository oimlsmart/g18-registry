<script setup lang="ts">
import { computed } from "vue";
import termsData from "@/data/terms.json";
import editionStats from "@/data/edition-stats.json";
import conflictsData from "@/data/conflicts.json";
import SLink from "@/components/SLink.vue";

const terms = termsData as any[];
const stats202X = (editionStats.stats || []).find((s: any) => s.edition === "202X");
const rawConflicts = Object.values(conflictsData.raw || {}).flat() as any[];

const readinessItems = computed(() => {
  const items: { label: string; status: "done" | "warn" | "todo"; detail: string; link?: string }[] = [];

  // ID conflicts
  items.push({
    label: "Resolve ID conflicts",
    status: rawConflicts.length > 0 ? "warn" : "done",
    detail: rawConflicts.length > 0
      ? `${rawConflicts.length} ID conflicts remaining`
      : "All ID conflicts resolved",
    link: rawConflicts.length > 0 ? "/g18/conflicts/" : undefined,
  });

  // Concept coverage
  items.push({
    label: "Concept coverage",
    status: "done",
    detail: `${stats202X?.terms || 0} concepts in G 18:202X`,
  });

  // Publication instances
  items.push({
    label: "Publication instances",
    status: "done",
    detail: `${stats202X?.instances || 0} term instances across OIML publications`,
  });

  // Definitions populated
  const withDef = terms.filter(t => (t.publications || []).some(p => p.definition?.trim())).length;
  const withoutDef = terms.length - withDef;
  items.push({
    label: "Definitions populated",
    status: withoutDef > 10 ? "warn" : "done",
    detail: `${withDef}/${terms.length} concepts have definitions${withoutDef > 0 ? ` (${withoutDef} missing)` : ""}`,
  });

  return items;
});

const allDone = computed(() => readinessItems.value.every(i => i.status === "done"));
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb">
      <SLink to="/">Registry</SLink> / <SLink to="/g18/editions/">G 18</SLink> / <span>202X readiness</span>
    </div>
    <h1>G 18:202X — publication readiness</h1>
    <p class="lede">The draft 2nd edition nearing publication.</p>
  </div>

  <div :class="['readiness-banner', allDone ? 'readiness-ready' : 'readiness-warn']">
    <span class="readiness-icon">{{ allDone ? "✅" : "⚠️" }}</span>
    <div>
      <div class="readiness-title">{{ allDone ? "Ready to publish" : "Blocking issues remain" }}</div>
      <div class="readiness-text">
        {{ allDone
          ? "All readiness checks passed. G 18:202X can be published."
          : "Resolve the items below before publishing G 18:202X." }}
      </div>
    </div>
  </div>

  <section class="card">
    <h2>Readiness checklist</h2>
    <div class="checklist">
      <div v-for="(item, i) in readinessItems" :key="i" :class="['checklist-item', `checklist-${item.status}`]">
        <span class="checklist-icon">
          {{ item.status === "done" ? "✓" : item.status === "warn" ? "⚠" : "○" }}
        </span>
        <div class="checklist-body">
          <div class="checklist-label">{{ item.label }}</div>
          <div class="checklist-detail">{{ item.detail }}</div>
        </div>
        <SLink v-if="item.link" :to="item.link" class="checklist-link">Resolve →</SLink>
      </div>
    </div>
  </section>

  <section class="card">
    <h2>What G 18:202X contains</h2>
    <div class="grid grid-4">
      <div class="stat-card"><div class="stat-value">{{ stats202X?.terms || 0 }}</div><div class="stat-label">concepts</div></div>
      <div class="stat-card"><div class="stat-value">{{ stats202X?.instances || 0 }}</div><div class="stat-label">instances</div></div>
      <div class="stat-card"><div class="stat-value">{{ stats202X?.only_in_edition || 0 }}</div><div class="stat-label">new in 202X</div></div>
      <div class="stat-card"><div class="stat-value">{{ stats202X?.harmonization_candidates || 0 }}</div><div class="stat-label">harmonization candidates</div></div>
    </div>
  </section>

  <section class="card" v-if="rawConflicts.length > 0">
    <h2>ID conflicts ({{ rawConflicts.length }})</h2>
    <p class="muted">These must be resolved before publication.</p>
    <SLink to="/g18/conflicts/" class="external">View all conflicts →</SLink>
  </section>
</template>

<style scoped>
.readiness-banner {
  display: flex;
  align-items: flex-start;
  gap: 0.8em;
  padding: 1em 1.2em;
  border-radius: 6px;
  border-left: 4px solid;
  margin-bottom: 1.2em;
}
.readiness-ready { background: var(--status-ok-bg); border-color: var(--status-ok-border); color: var(--status-ok-text); }
.readiness-warn { background: var(--status-warn-bg); border-color: var(--status-warn-border); color: var(--status-warn-text); }
.readiness-icon { font-size: 1.5rem; }
.readiness-title { font-weight: 600; font-size: 1rem; }
.readiness-text { font-size: 0.85rem; margin-top: 0.15em; }

.checklist { display: flex; flex-direction: column; gap: 0.5em; }
.checklist-item { display: flex; align-items: center; gap: 0.7em; padding: 0.5em 0; border-bottom: 1px solid var(--color-rule-soft); }
.checklist-item:last-child { border-bottom: 0; }
.checklist-icon { width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-weight: 700; }
.checklist-done .checklist-icon { color: var(--status-ok-text); }
.checklist-warn .checklist-icon { color: var(--status-warn-text); }
.checklist-todo .checklist-icon { color: var(--color-ink-muted); }
.checklist-body { flex: 1; }
.checklist-label { font-weight: 600; font-size: 0.9rem; color: var(--color-ink); }
.checklist-detail { font-size: 0.82rem; color: var(--color-ink-soft); }
.checklist-link { font-size: 0.82rem; font-weight: 600; white-space: nowrap; }
</style>
