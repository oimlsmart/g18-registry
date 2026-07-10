<script setup lang="ts">
import { computed, ref } from "vue";
import tcData from "@/data/tc.json";
import publicationsData from "@/data/publications.json";
import termsData from "@/data/terms.json";
import { useSuggestedActions, ACTION_META, actionMeta, slugifyPubId } from "@/composables/useSuggestedActions";
import SLink from "@/components/SLink.vue";
import { kindLabel, slugify } from "@/utils/term-utils";

const props = defineProps<{ slug: string }>();

const tcName = computed(() => (tcData as string[]).find(t => slugify(t) === props.slug));
const terms = termsData as any[];
const publications = publicationsData as any[];
const { forTCSC } = useSuggestedActions(terms);

// Edition filter (sticky 3-button pattern, default 202X). Filters by which
// edition this TC/SC's pubs have instances in.
type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");
const editionForFilter = computed<string | null>(() =>
  editionFilter.value === "all" ? null : editionFilter.value
);

// This TC/SC's publications — filtered by whether they have any term
// instance in the selected edition.
const tcPubs = computed(() => {
  if (!tcName.value) return [];
  const ed = editionForFilter.value;
  if (!ed) return publications.filter(p => p.tc_sc === tcName.value);
  const pubIds = new Set<string>();
  for (const t of terms) {
    for (const p of (t.publications || [])) {
      if (p.tc_sc === tcName.value && p.edition === ed) pubIds.add(p.publication_id);
    }
  }
  return publications.filter(p => p.tc_sc === tcName.value && pubIds.has(p.id));
});
const tcTerms = computed(() => {
  if (!tcName.value) return [];
  const ed = editionForFilter.value;
  return terms.filter(t => t.publications.some((p: any) =>
    p.tc_sc === tcName.value && (ed === null || p.edition === ed)
  ));
});

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


// ── Action list view modes ────────────────────────────────────────────
type ViewMode = "by-action" | "by-pub" | "alphabetical";
const viewMode = ref<ViewMode>("by-action");

interface Row {
  slug: string;
  name: string;
  type: string;
  priority: string;
  description: string;
  kind: string;
  // publication IDs under this TC/SC where this term has the action
  sourcePubIds: string[];
}

const actionRows = computed<Row[]>(() => {
  const out: Row[] = [];
  for (const a of tcActions.value) {
    const t = terms.find(x => x.slug === a.slug);
    if (!t) continue;
    // Only count publications under THIS tc/sc (actions come from across all pubs,
    // but the secretary only controls their own).
    const sourcePubIds = (t.publications || [])
      .filter((p: any) => p.tc_sc === tcName.value)
      .map((p: any) => p.publication_id);
    out.push({
      slug: a.slug, name: a.name, type: a.type, priority: a.priority,
      description: a.description,
      kind: t?.kind || "oiml_original",
      sourcePubIds: [...new Set(sourcePubIds)],
    });
  }
  return out;
});

const sortedRows = computed<Row[]>(() => {
  const r = actionRows.value;
  if (viewMode.value === "alphabetical") {
    return [...r].sort((a, b) => a.name.localeCompare(b.name));
  }
  if (viewMode.value === "by-pub") {
    return [...r].sort((a, b) => {
      const pa = a.sourcePubIds[0] || "";
      const pb = b.sourcePubIds[0] || "";
      if (pa !== pb) return pa.localeCompare(pb);
      return a.name.localeCompare(b.name);
    });
  }
  // by-action
  const typeOrder = ["upgrade_vim", "upgrade_viml", "removed", "harmonize", "adopt_vim", "adopt_viml", "standardize", "unique"];
  return [...r].sort((a, b) => {
    const ta = typeOrder.indexOf(a.type);
    const tb = typeOrder.indexOf(b.type);
    if (ta !== tb) return (ta < 0 ? 99 : ta) - (tb < 0 ? 99 : tb);
    return a.name.localeCompare(b.name);
  });
});

const viewModes: { val: ViewMode; label: string }[] = [
  { val: "by-action", label: "Group by action" },
  { val: "by-pub", label: "Group by publication" },
  { val: "alphabetical", label: "A–Z" },
];

const legendTypes = computed(() => {
  const set = new Set(actionRows.value.map(r => r.type));
  return Object.keys(ACTION_META).filter(t => set.has(t));
});

// Lookup publication reference for display
function pubRef(id: string): string {
  return publications.find(p => p.id === id)?.reference || id;
}
</script>

<template>
  <div v-if="!tcName" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/tc/">TC / SC</SLink> / <span>{{ tcName }}</span></div>
      <h1>{{ tcName }}</h1>
      <p class="lede">Aggregated view for the TC/SC secretary.</p>
    </div>

    <!-- Sticky page-level edition filter -->
    <div class="page-filter" role="region" aria-label="Edition filter">
      <span class="page-filter-label">Edition scope</span>
      <div class="page-filter-controls">
        <button type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
                @click="editionFilter = '202X'">
          <span class="page-filter-btn-title">202X</span>
          <span class="page-filter-btn-meta">draft, TC 1 acts here</span>
        </button>
        <button type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
                @click="editionFilter = '2010'">
          <span class="page-filter-btn-title">2010</span>
          <span class="page-filter-btn-meta">historic, read-only</span>
        </button>
        <button type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' }]"
                @click="editionFilter = 'all'">
          <span class="page-filter-btn-title">All</span>
          <span class="page-filter-btn-meta">both editions</span>
        </button>
      </div>
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
              <td><SLink :to="`/publications/${slugifyPubId(s.pub.id)}/`">{{ s.pub.reference || s.pub.id }}</SLink></td>
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

    <!-- Action list with view modes -->
    <section v-if="tcActions.length" class="card">
      <div class="card-head">
        <h2>Suggested actions ({{ tcActions.length }})</h2>
        <div class="sort-toggle" role="group" aria-label="View mode">
          <button v-for="m in viewModes" :key="m.val"
            type="button"
            :class="['sort-btn', { 'sort-btn-active': viewMode === m.val }]"
            @click="viewMode = m.val"
          >{{ m.label }}</button>
        </div>
      </div>

      <!-- Action icon legend -->
      <div class="action-legend">
        <span class="action-legend-title">Legend:</span>
        <span v-for="t in legendTypes" :key="t" class="action-legend-item">
          <span class="action-icon" :class="`action-icon-${t}`">{{ actionMeta(t).icon }}</span>
          <span class="action-legend-label">{{ actionMeta(t).label }}</span>
        </span>
      </div>

      <div class="table-scroll">
        <table>
          <thead><tr>
            <th v-if="viewMode !== 'alphabetical'">Action</th>
            <th>Term</th>
            <th v-if="viewMode === 'by-pub'">Publication</th>
            <th v-if="viewMode !== 'by-pub'">Publications</th>
            <th>What to decide</th>
          </tr></thead>
          <tbody>
            <tr v-for="r in sortedRows" :key="r.slug + r.type">
              <td v-if="viewMode !== 'alphabetical'">
                <span class="action-icon" :class="`action-icon-${r.type}`" :title="actionMeta(r.type).label">{{ actionMeta(r.type).icon }}</span>
              </td>
              <td class="term-cell"><SLink :to="`/terms/${r.slug}/`">{{ r.name }}</SLink></td>
              <td v-if="viewMode === 'by-pub'">
                <SLink v-if="r.sourcePubIds[0]" :to="`/publications/${slugifyPubId(r.sourcePubIds[0])}/`">{{ pubRef(r.sourcePubIds[0]) }}</SLink>
                <span v-if="r.sourcePubIds.length > 1" class="muted"> +{{ r.sourcePubIds.length - 1 }}</span>
              </td>
              <td v-else>
                <SLink v-for="pid in r.sourcePubIds" :key="pid" :to="`/publications/${slugifyPubId(pid)}/`" class="src-pub-link">{{ pubRef(pid) }}</SLink>
              </td>
              <td><span class="muted" style="font-size:0.88em">{{ actionMeta(r.type).hint }}</span></td>
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
              <td class="term-cell"><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
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
.src-pub-link {
  display: inline-block;
  margin-right: 0.6em;
  margin-bottom: 0.2em;
  font-size: 0.85em;
}
</style>
