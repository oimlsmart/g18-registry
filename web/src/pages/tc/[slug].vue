<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import tcData from "@/data/tc.json";
import publicationsData from "@/data/publications.json";
import termsData from "@/data/terms.json";
import { useSuggestedActions } from "@/composables/useSuggestedActions";

const route = useRoute();
function slugify(name: string) { return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }

const tcName = computed(() => (tcData as string[]).find(t => slugify(t) === route.params.slug));
const terms = termsData as any[];
const publications = publicationsData as any[];
const { forTCSC } = useSuggestedActions(terms);

// This TC/SC's publications
const tcPubs = computed(() => !tcName.value ? [] : publications.filter(p => p.tc_sc === tcName.value));
const tcTerms = computed(() => !tcName.value ? [] : terms.filter(t => t.publications.some((p: any) => p.tc_sc === tcName.value)));

// Actions for this TC/SC
const tcActions = computed(() => !tcName.value ? [] : forTCSC(tcName.value));
const actionTermSlugs = computed(() => new Set(tcActions.value.map(a => a.slug)));

// Per-publication status
const pubStatus = computed(() => tcPubs.value.map(pub => {
  const pubTermSlugs = new Set(
    terms.filter(t => t.publications.some((p: any) => p.publication_id === pub.id)).map(t => t.slug)
  );
  const pubActionsForThis = tcActions.value.filter(a => pubTermSlugs.has(a.slug));
  const totalTerms = terms.filter(t => t.publications.some((p: any) => p.publication_id === pub.id)).length;
  return {
    pub,
    totalTerms,
    actionsNeeded: pubActionsForThis.length,
    status: pubActionsForThis.length === 0 ? "clean" : "attention",
  };
}));

const cleanCount = computed(() => pubStatus.value.filter(s => s.status === "clean").length);
const attentionCount = computed(() => pubStatus.value.filter(s => s.status === "attention").length);

const typeLabels: Record<string, string> = {
  upgrade_vim: "Upgrade VIM", upgrade_viml: "Upgrade VIML",
  removed: "Removed", harmonize: "Harmonize",
  standardize: "Standardize", unique: "Unique",
};

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }
</script>

<template>
  <div v-if="!tcName" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/tc/">TC / SC</SLink> / <span>{{ tcName }}</span></div>
      <h1>{{ tcName }}</h1>
      <p class="lede">Aggregated view for the TC/SC secretary.</p>
    </div>

    <!-- Dashboard tiles -->
    <section class="card">
      <h2>Dashboard</h2>
      <div class="prov-grid">
        <div class="prov-tile">
          <div class="prov-tile-num">{{ tcPubs.length }}</div>
          <div class="prov-tile-label">Publications</div>
        </div>
        <div class="prov-tile prov-tile-warn" v-if="attentionCount">
          <div class="prov-tile-num">{{ attentionCount }}</div>
          <div class="prov-tile-label">Need attention</div>
        </div>
        <div class="prov-tile">
          <div class="prov-tile-num">{{ cleanCount }}</div>
          <div class="prov-tile-label">Clean</div>
        </div>
        <div class="prov-tile">
          <div class="prov-tile-num">{{ tcActions.length }}</div>
          <div class="prov-tile-label">Terms with actions</div>
        </div>
      </div>
    </section>

    <!-- Per-publication breakdown -->
    <section v-if="pubStatus.length" class="card">
      <h2>Publications</h2>
      <div class="table-scroll">
        <table>
          <thead>
            <tr>
              <th>Publication</th>
              <th>Year</th>
              <th>Terms</th>
              <th>Actions needed</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in pubStatus" :key="s.pub.id">
              <td><SLink :to="`/publications/${s.pub.id}/`">{{ s.pub.reference || s.pub.id }}</SLink></td>
              <td class="num">{{ (s.pub.id || '').match(/(\d{4})/)?.[1] || "—" }}</td>
              <td class="num">{{ s.totalTerms }}</td>
              <td class="num">{{ s.actionsNeeded }}</td>
              <td>
                <span v-if="s.status === 'clean'" class="badge badge-ok">Clean</span>
                <span v-else class="badge badge-partial">Needs attention</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Action list -->
    <section v-if="tcActions.length" class="card">
      <h2>Suggested actions ({{ tcActions.length }})</h2>
      <div class="table-scroll">
        <table>
          <thead><tr><th>Term</th><th>Action</th><th>Description</th></tr></thead>
          <tbody>
            <tr v-for="a in tcActions.slice().sort((a,b) => a.name.localeCompare(b.name))" :key="a.slug + a.type">
              <td><SLink :to="`/terms/${a.slug}/`">{{ a.name }}</SLink></td>
              <td><span class="action-pill" :class="`action-pill-${a.priority}`">{{ typeLabels[a.type] || a.type }}</span></td>
              <td>{{ a.description }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- All terms -->
    <section class="card">
      <h2>All terms ({{ tcTerms.length }})</h2>
      <div class="table-scroll">
        <table>
          <thead><tr><th>Term</th><th>VIM</th><th>Instances</th><th>Action?</th></tr></thead>
          <tbody>
            <tr v-for="t in tcTerms" :key="t.slug">
              <td><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
              <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
              <td class="num">{{ t.publications.filter((p: any) => p.tc_sc === tcName).length }}</td>
              <td>
                <span v-if="actionTermSlugs.has(t.slug)" class="badge badge-partial">Yes</span>
                <span v-else class="badge badge-ok">Clean</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </template>
</template>

<style scoped>
.prov-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.7em; margin: 0.5em 0; }
.prov-tile { padding: 0.8em 1em; background: var(--accent-tint); border-radius: 5px; border-left: 3px solid var(--accent); }
.prov-tile-warn { background: #fffbeb; border-left-color: var(--oiml-amber-deep); }
.prov-tile-num { font-size: 1.8em; font-weight: 700; color: var(--accent); line-height: 1; }
.prov-tile-warn .prov-tile-num { color: var(--oiml-amber-deep); }
.prov-tile-label { font-size: 0.85em; color: var(--ink-soft); margin-top: 0.2em; }
@media (max-width: 600px) { .prov-grid { grid-template-columns: repeat(2, 1fr); } }
</style>
