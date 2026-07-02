<script setup lang="ts">
import { computed, ref } from "vue";
import termsData from "@/data/terms.json";

const terms = termsData as any[];
const filterPriority = ref<"" | "high" | "medium" | "info">("");
const search = ref("");

function distinctDefs(t: any): number {
  return new Set(t.publications.map((p: any) => (p.definition || "").trim()).filter(Boolean)).size;
}

type Action = {
  priority: "high" | "medium" | "info";
  term: string;
  slug: string;
  reason: string;
  detail: string;
  count: number;
  kind: string;
  pubs: number;
};

const allActions = computed<Action[]>(() => {
  const actions: Action[] = [];
  for (const t of terms) {
    const dd = distinctDefs(t);
    const lc = t.latest_check;
    const oc = t.official_concept;

    // HIGH: cites superseded VIM AND not in latest
    if (lc && !lc.found) {
      actions.push({ priority: "high", term: t.name, slug: t.slug, reason: `Cites ${oc?.edition_label}, NOT in ${lc.latest_label}`, detail: lc.latest_label, count: t.publications.length, kind: t.kind, pubs: t.publications.length });
    }
    // HIGH: cites superseded VIM AND IS in latest (needs comparison)
    if (lc && lc.found && oc && lc.concept_id !== oc.id) {
      actions.push({ priority: "high", term: t.name, slug: t.slug, reason: `In ${lc.latest_label} as #${lc.concept_id} (different from cited #${oc.id})`, detail: lc.latest_label, count: t.publications.length, kind: t.kind, pubs: t.publications.length });
    }
    // HIGH: 5+ divergent definitions
    if (dd >= 5) {
      actions.push({ priority: "high", term: t.name, slug: t.slug, reason: `${dd} distinct definitions across ${t.publications.length} publications`, detail: `${dd} defs`, count: dd, kind: t.kind, pubs: t.publications.length });
    }
    // MEDIUM: 3-4 divergent definitions
    else if (dd >= 3) {
      actions.push({ priority: "medium", term: t.name, slug: t.slug, reason: `${dd} distinct definitions`, detail: `${dd} defs`, count: dd, kind: t.kind, pubs: t.publications.length });
    }
    // INFO: high harmonisation value
    if (t.publications.length >= 10 && dd < 3) {
      actions.push({ priority: "info", term: t.name, slug: t.slug, reason: `Cited by ${t.publications.length} publications`, detail: `${t.publications.length} pubs`, count: t.publications.length, kind: t.kind, pubs: t.publications.length });
    }
  }

  const order = { high: 0, medium: 1, info: 2 };
  return actions.sort((a, b) => {
    const po = (order[a.priority] ?? 9) - (order[b.priority] ?? 9);
    if (po !== 0) return po;
    return (b.count || 0) - (a.count || 0);
  });
});

const filtered = computed(() => {
  let a = allActions.value;
  if (filterPriority.value) a = a.filter(x => x.priority === filterPriority.value);
  if (search.value) {
    const q = search.value.toLowerCase();
    a = a.filter(x => x.term?.toLowerCase().includes(q));
  }
  return a;
});

const counts = computed(() => ({
  all: allActions.value.length,
  high: allActions.value.filter(a => a.priority === "high").length,
  medium: allActions.value.filter(a => a.priority === "medium").length,
  info: allActions.value.filter(a => a.priority === "info").length,
}));

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
</script>

<template>
  <div class="page-head">
    <div class="breadcrumb"><SLink to="/">Registry</SLink> / <span>Priority actions</span></div>
    <h1>Priority actions for TC 1</h1>
    <p class="lede">{{ allActions.length }} total actions across {{ terms.length }} terms.</p>
  </div>

  <section class="card">
    <form style="display:flex;gap:1em;flex-wrap:wrap;align-items:center;margin-bottom:0.5em" @submit.prevent>
      <input v-model="search" type="search" placeholder="Search term…" style="padding:0.3em 0.5em;min-width:14em;border:1px solid var(--rule);border-radius:3px" />
      <button v-for="p in [
        { val: '', label: `All (${counts.all})` },
        { val: 'high', label: `HIGH (${counts.high})` },
        { val: 'medium', label: `MEDIUM (${counts.medium})` },
        { val: 'info', label: `INFO (${counts.info})` },
      ]" :key="p.val"
        @click.prevent="filterPriority = p.val as any"
        :style="{
          padding: '0.2em 0.6em', borderRadius: '3px', cursor: 'pointer', border: '1px solid var(--rule)',
          background: filterPriority === p.val ? 'var(--accent)' : '#fff',
          color: filterPriority === p.val ? '#fff' : 'var(--ink-soft)',
          fontWeight: filterPriority === p.val ? '600' : '400',
        }"
      >{{ p.label }}</button>
    </form>

    <table>
      <thead>
        <tr>
          <th style="width:5em">Priority</th>
          <th>Term</th>
          <th>VIM</th>
          <th>Issue</th>
          <th>Pubs</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(a, i) in filtered" :key="i">
          <td><span :class="['action-pill', `action-pill-${a.priority}`]">{{ a.priority.toUpperCase() }}</span></td>
          <td><SLink :to="`/terms/${a.slug}/`">{{ a.term }}</SLink></td>
          <td><span :class="['kind', `kind-${a.kind}`]">{{ kindLabel(a.kind) }}</span></td>
          <td>{{ a.reason }}</td>
          <td class="num">{{ a.pubs }}</td>
          <td><SLink :to="`/terms/${a.slug}/`">Open →</SLink></td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
