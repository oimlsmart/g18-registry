<script setup lang="ts">
import { computed, ref } from "vue";
import { useJsonFetch } from "@/composables/useJsonFetch";
import tcData from "@/data/tc.json";
import { ACTION_META, actionMeta, actionTypeRank } from "@/composables/action-utils";
import SLink from "@/components/SLink.vue";
import { kindLabel, slugify } from "@/utils/term-utils";

const props = defineProps<{ slug: string }>();
const base = import.meta.env.BASE_URL;

const tcName = computed(() => (tcData as string[]).find(t => slugify(t) === props.slug));
const { data: tcData_response, loading } = useJsonFetch(() => `${base}data/tcs/${props.slug}.json`);
const terms = computed(() => tcData_response.value?.terms || []);
const publications = computed(() => tcData_response.value?.publications || []);

// This TC/SC's publications — no edition filter, show all.
const tcPubs = computed(() => {
  if (!tcName.value) return [];
  return publications.value.filter(p => p.tc_sc === tcName.value);
});
const tcTerms = computed(() => {
  if (!tcName.value) return [];
  return terms.value.filter(t => t.publications.some((p: any) =>
    p.tc_sc === tcName.value
  ));
});

// Actions for this TC/SC
const tcActions = computed(() => {
  if (!tcName.value) return [];
  const out: any[] = [];
  for (const t of terms.value) {
    for (const a of (t.suggested_actions || [])) {
      const pids = a["publication_ids"] || [];
      const hasTCPub = (t.publications || []).some((p: any) =>
        p.tc_sc === tcName.value && pids.includes(p.publication_id)
      );
      if (pids.length === 0 || hasTCPub) {
        out.push({ ...a, slug: t.slug, name: t.name });
      }
    }
  }
  return out;
});
const actionTermSlugs = computed(() => new Set(tcActions.value.map(a => a.slug)));

// Per-publication status
const pubStatus = computed(() => tcPubs.value.map(pub => {
  const pubTermSlugs = new Set(
    terms.value.filter(t => t.publications.some((p: any) => p.publication_id === pub.id)).map(t => t.slug)
  );
  const pubActionsForThis = tcActions.value.filter(a => pubTermSlugs.has(a.slug));
  const totalTerms = terms.value.filter(t => t.publications.some((p: any) => p.publication_id === pub.id)).length;
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
    const t = terms.value.find(x => x.slug === a.slug);
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
  return [...r].sort((a, b) => {
    const ta = actionTypeRank(a.type);
    const tb = actionTypeRank(b.type);
    if (ta !== tb) return ta - tb;
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
  return publications.value.find(p => p.id === id)?.reference || id;
}
</script>

<template>
  <div v-if="loading" class="card"><p style="color: var(--color-ink-muted)">Loading…</p></div>
  <div v-else-if="!tcName" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/tc/">TC / SC</SLink> / <span>{{ tcName }}</span></div>
      <h1>{{ tcName }}</h1>
      <p class="lede">Aggregated view for the TC/SC secretary.</p>
    </div>

    <!-- G 18 edition filter removed — show all instances regardless of edition -->

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
              <td><SLink :to="`/publications/${slugify(s.pub.id)}/`">{{ s.pub.reference || s.pub.id }}</SLink></td>
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
              <td class="term-cell"><SLink :to="`/concepts/${r.slug}/`">{{ r.name }}</SLink></td>
              <td v-if="viewMode === 'by-pub'">
                <SLink v-if="r.sourcePubIds[0]" :to="`/publications/${slugify(r.sourcePubIds[0])}/`">{{ pubRef(r.sourcePubIds[0]) }}</SLink>
                <span v-if="r.sourcePubIds.length > 1" class="muted"> +{{ r.sourcePubIds.length - 1 }}</span>
              </td>
              <td v-else>
                <SLink v-for="pid in r.sourcePubIds" :key="pid" :to="`/publications/${slugify(pid)}/`" class="src-pub-link">{{ pubRef(pid) }}</SLink>
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
              <td class="term-cell"><SLink :to="`/concepts/${t.slug}/`">{{ t.name }}</SLink></td>
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
