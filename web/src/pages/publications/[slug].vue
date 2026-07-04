<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import publications from "@/data/publications.json";
import termsData from "@/data/terms.json";
import { useSuggestedActions } from "@/composables/useSuggestedActions";

const route = useRoute();
const pubId = computed(() => route.params.slug as string);
const pub = computed(() => (publications as any[]).find(p => p.id === pubId.value));
const terms = termsData as any[];
const { forPublication } = useSuggestedActions(terms);

const pubTerms = computed(() => terms.filter(t => t.publications.some((p: any) => p.publication_id === pubId.value)));
function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }

// Suggested actions for THIS publication, grouped by type
const pubActions = computed(() => forPublication(pubId.value));
const actionTerms = computed(() => {
  const slugs = new Set(pubActions.value.map(a => a.slug));
  return terms.filter(t => slugs.has(t.slug));
});
const cleanTerms = computed(() => {
  const actionSlugs = new Set(pubActions.value.map(a => a.slug));
  return pubTerms.value.filter(t => !actionSlugs.has(t.slug));
});

const typeLabels: Record<string, string> = {
  upgrade_vim: "Upgrade VIM citation", upgrade_viml: "Upgrade VIML citation",
  removed: "Not in latest edition", harmonize: "Harmonize with other pubs",
  standardize: "Ready to standardize", unique: "Unique to this publication",
};
</script>

<template>
  <div v-if="!pub" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/publications/">Publications</SLink> / <span>{{ pub.reference || pub.id }}</span></div>
      <h1>{{ pub.reference || pub.id }}</h1>
      <p class="lede">
        {{ pubTerms.length }} terms
        <span v-if="pub.tc_sc"> · TC/SC: {{ pub.tc_sc }}</span>
        <span v-if="pub.year"> · {{ pub.year }}</span>
        <a v-if="pub.link" class="external" :href="pub.link" style="margin-left:0.6em">PDF ↗</a>
      </p>
    </div>

    <!-- Summary tiles -->
    <section class="card">
      <h2>Action summary</h2>
      <div class="prov-grid">
        <div class="prov-tile prov-tile-warn">
          <div class="prov-tile-num">{{ pubActions.length }}</div>
          <div class="prov-tile-label">Terms needing action</div>
        </div>
        <div class="prov-tile">
          <div class="prov-tile-num">{{ cleanTerms.length }}</div>
          <div class="prov-tile-label">Terms clean (no action)</div>
        </div>
        <div class="prov-tile">
          <div class="prov-tile-num">{{ pubTerms.length }}</div>
          <div class="prov-tile-label">Total terms</div>
        </div>
      </div>
    </section>

    <!-- Action list sorted by term -->
    <section v-if="pubActions.length" class="card">
      <h2>Suggested actions (sorted by term)</h2>
      <div class="table-scroll">
        <table>
          <thead><tr><th>Term</th><th>Action</th><th>Description</th></tr></thead>
          <tbody>
            <tr v-for="a in pubActions.slice().sort((a,b) => a.name.localeCompare(b.name))" :key="a.slug + a.type">
              <td><SLink :to="`/terms/${a.slug}/`">{{ a.name }}</SLink></td>
              <td><span class="action-pill" :class="`action-pill-${a.priority}`">{{ typeLabels[a.type] || a.type }}</span></td>
              <td>{{ a.description }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Clean terms -->
    <section v-if="cleanTerms.length" class="card">
      <h2>Clean terms ({{ cleanTerms.length }})</h2>
      <p class="lede">No action needed — these terms match the authoritative baseline.</p>
      <div class="table-scroll">
        <table>
          <thead><tr><th>Term</th><th>VIM</th><th>Definition</th></tr></thead>
          <tbody>
            <tr v-for="t in cleanTerms" :key="t.slug">
              <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
              <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
              <td style="max-width:540px">{{ t.publications.find((p: any) => p.publication_id === pubId)?.definition }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </template>
</template>

<style scoped>
.prov-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.7em; margin: 0.5em 0; }
.prov-tile { padding: 0.8em 1em; background: var(--accent-tint); border-radius: 5px; border-left: 3px solid var(--accent); }
.prov-tile-warn { background: #fffbeb; border-left-color: var(--oiml-amber-deep); }
.prov-tile-num { font-size: 1.8em; font-weight: 700; color: var(--accent); line-height: 1; }
.prov-tile-warn .prov-tile-num { color: var(--oiml-amber-deep); }
.prov-tile-label { font-size: 0.85em; color: var(--ink-soft); margin-top: 0.2em; }
@media (max-width: 600px) { .prov-grid { grid-template-columns: 1fr; } }
</style>
