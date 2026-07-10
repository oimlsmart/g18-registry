<script setup lang="ts">
import { computed, ref } from "vue";
import publications from "@/data/publications.json";
import termsData from "@/data/terms.json";
import { useSuggestedActions, ACTION_META, actionMeta, slugifyPubId } from "@/composables/useSuggestedActions";

const props = defineProps<{ slug: string }>();
const slugParam = computed(() => props.slug);
// Resolve the publication: accept either the slugified id (preferred) or
// the raw id (backwards compat with old links). The slug map is built once.
const pubBySlug = computed(() => {
  const map: Record<string, string> = {};
  for (const p of (publications as any[])) map[slugifyPubId(p.id)] = p.id;
  return map;
});
const pubId = computed(() => {
  const param = slugParam.value;
  // Try direct ID match first (backwards compat), then slug lookup.
  if ((publications as any[]).some(p => p.id === param)) return param;
  return pubBySlug.value[param] || param;
});
const pub = computed(() => (publications as any[]).find(p => p.id === pubId.value));
const terms = termsData as any[];
const { forPublication } = useSuggestedActions(terms);

const pubTerms = computed(() => terms.filter(t => t.publications.some((p: any) => p.publication_id === pubId.value)));
function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }

// Edition toggle. Default: 202X — TC 1 can only act on the draft edition.
type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("202X");

// Which editions does this pub appear in for the given term?
function editionsForTerm(term: any): Set<string> {
  const eds = new Set<string>();
  for (const p of (term.publications || [])) {
    if (p.publication_id === pubId.value && p.edition) eds.add(p.edition);
  }
  return eds;
}

// Filter terms by whether this pub has an instance in the selected edition.
function termMatchesEdition(term: any): boolean {
  if (editionFilter.value === "all") return true;
  return editionsForTerm(term).has(editionFilter.value);
}
const filteredPubTerms = computed(() => pubTerms.value.filter(termMatchesEdition));

// "Needs action" = a real defect (citation outdated, divergent definitions,
// adoption gap). Pure-information actions (OIML-original, ready-to-
// standardize) do NOT count as defects — a term that is OIML-original and
// cited consistently across all pubs is clean, not action-required.
const DEFECT_ACTION_TYPES = new Set([
  "upgrade_vim", "upgrade_viml", "removed",
  "harmonize", "adopt_vim", "adopt_viml",
]);

// All actions where this pub is in publication_ids — filtered by whether
// the term has a pub instance in the selected edition AND the action
// actually applies to that edition. Without this scoping, a 2010-only
// instance of this pub would surface 202X-targeted actions for terms
// where the action really applies to a different pub, AND 2010-only
// harmonize actions would leak into the 202X view.
function actionAppliesToEdition(a: any, edition: string): boolean {
  if (edition === "all") return true;
  const meta = actionMeta(a.type);
  if (meta.applies_to === "all") return true;
  // Action is edition-specific (most are 202X-only).
  // harmonize is scoped to a worst-edition during compile, so respect
  // the selected edition filter as a proxy.
  return meta.applies_to === edition || a.type === "harmonize";
}

const pubActions = computed(() => {
  const all = forPublication(pubId.value);
  // For the publication detail page we only surface DEFECT actions in the
  // "needs action" list. Info actions (unique, standardize) are positive
  // or neutral — they don't belong in a worklist of problems to fix.
  return all.filter(a => {
    if (!DEFECT_ACTION_TYPES.has(a.type)) return false;
    if (editionFilter.value === "all") return true;
    const t = terms.find(t => t.slug === a.slug);
    if (!t) return false;
    return editionsForTerm(t).has(editionFilter.value) &&
           actionAppliesToEdition(a, editionFilter.value);
  });
});

// Unique terms with at least one action — what the tile count reflects.
// pubActions.length over-counts because a term can have multiple actions.
const pubActionTermSlugs = computed(() => new Set(pubActions.value.map(a => a.slug)));
const pubActionTermCount = computed(() => pubActionTermSlugs.value.size);

const actionTerms = computed(() => terms.filter(t => pubActionTermSlugs.value.has(t.slug)));
const cleanTerms = computed(() => filteredPubTerms.value.filter(t => !pubActionTermSlugs.value.has(t.slug)));

// Edition counts for the toggle UI (so users see "202X: 7 · 2010: 119 · All: 126")
const editionCounts = computed(() => {
  const c = { "202X": 0, "2010": 0 };
  for (const t of pubTerms.value) {
    const eds = editionsForTerm(t);
    if (eds.has("202X")) c["202X"]++;
    if (eds.has("2010")) c["2010"]++;
  }
  return c;
});

type ViewMode = "by-action" | "by-clause" | "alphabetical";
const viewMode = ref<ViewMode>("by-action");

// Build rows enriched with clause + edition info for the publication.
interface Row {
  slug: string;
  name: string;
  type: string;
  priority: string;
  description: string;
  clause: string;
  edition: string;
  kind: string;
}

// Find the publication instance matching the active edition filter.
// A term may have both 2010 and 202X instances of this pub — picking the
// first match would leak 2010 data into the 202X view (and vice versa).
function pubInstanceForEdition(term: any): any {
  const pubs = (term?.publications || []).filter((p: any) => p.publication_id === pubId.value);
  if (editionFilter.value === "all") return pubs[0];
  return pubs.find((p: any) => p.edition === editionFilter.value) || pubs[0];
}

const actionRows = computed<Row[]>(() => {
  const rows: Row[] = [];
  for (const a of pubActions.value) {
    const t = terms.find(x => x.slug === a.slug);
    const pub = pubInstanceForEdition(t);
    rows.push({
      slug: a.slug, name: a.name, type: a.type, priority: a.priority,
      description: a.description,
      clause: pub?.clause || "—",
      edition: pub?.edition || "—",
      kind: t?.kind || "oiml_original",
    });
  }
  return rows;
});

const sortedRows = computed<Row[]>(() => {
  const r = actionRows.value;
  if (viewMode.value === "alphabetical") {
    return [...r].sort((a, b) => a.name.localeCompare(b.name));
  }
  if (viewMode.value === "by-clause") {
    return [...r].sort((a, b) => {
      // Numeric clause sort (T.2.10 → [T, 2, 10])
      const pa = (a.clause || "").split(/[.\s]/).map((x: string) => parseInt(x) || 0);
      const pb = (b.clause || "").split(/[.\s]/).map((x: string) => parseInt(x) || 0);
      for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
        const diff = (pa[i] || 0) - (pb[i] || 0);
        if (diff !== 0) return diff;
      }
      return a.name.localeCompare(b.name);
    });
  }
  // by-action: group by action type, then alphabetical within group
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
  { val: "by-clause", label: "List by clause" },
  { val: "alphabetical", label: "A–Z" },
];

const legendTypes = computed(() => {
  const set = new Set(actionRows.value.map(r => r.type));
  return Object.keys(ACTION_META).filter(t => set.has(t));
});

// Distinct action types present in this publication
const actionTypesPresent = computed(() => {
  const counts: Record<string, number> = {};
  for (const a of pubActions.value) counts[a.type] = (counts[a.type] || 0) + 1;
  return Object.entries(counts).sort(([,a],[,b]) => b - a);
});
</script>

<template>
  <div v-if="!pub" class="card"><p>Not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/publications/">Publications</SLink> / <span>{{ pub.reference || pub.id }}</span></div>
      <h1>{{ pub.reference || pub.id }}</h1>
      <p class="lede">
        {{ pubTerms.length }} terms
        <span v-if="pub.tc_sc"> · TC/SC: <SLink :to="`/tc/${(pub.tc_sc || '').toLowerCase().replace('/', '-')}/`">{{ pub.tc_sc }}</SLink></span>
        <span v-if="pub.year"> · {{ pub.year }}</span>
        <a v-if="pub.link" class="external" :href="pub.link" style="margin-left:0.6em">PDF ↗</a>
      </p>
    </div>

    <!-- Sticky page-level edition filter. TC 1 acts on 202X; 2010 is historic.
         The bar is sticky so users always see which edition scope is active
         as they scroll through the action list and tables below. -->
    <div class="page-filter" role="region" aria-label="Edition filter">
      <span class="page-filter-label">Edition scope</span>
      <div class="page-filter-controls">
        <button type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
                @click="editionFilter = '202X'">
          <span class="page-filter-btn-title">202X</span>
          <span class="page-filter-btn-meta">{{ editionCounts["202X"] }} terms · draft, TC 1 acts here</span>
        </button>
        <button type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
                @click="editionFilter = '2010'">
          <span class="page-filter-btn-title">2010</span>
          <span class="page-filter-btn-meta">{{ editionCounts["2010"] }} terms · historic, read-only</span>
        </button>
        <button type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' }]"
                @click="editionFilter = 'all'">
          <span class="page-filter-btn-title">All</span>
          <span class="page-filter-btn-meta">{{ pubTerms.length }} terms · both editions</span>
        </button>
      </div>
    </div>

    <!-- Summary tiles -->
    <section class="card">
      <h2>Action summary</h2>
      <div class="prov-grid">
        <div class="prov-tile prov-tile-warn">
          <div class="prov-tile-num">{{ pubActionTermCount }}</div>
          <div class="prov-tile-label">Terms in {{ pub.reference || pub.id }} needing action ({{ editionFilter === "all" ? "all editions" : editionFilter }})</div>
        </div>
        <div class="prov-tile">
          <div class="prov-tile-num">{{ cleanTerms.length }}</div>
          <div class="prov-tile-label">Terms clean (no action)</div>
        </div>
        <div class="prov-tile">
          <div class="prov-tile-num">{{ filteredPubTerms.length }}</div>
          <div class="prov-tile-label">Total terms cited ({{ editionFilter === "all" ? "all editions" : editionFilter }})</div>
        </div>
      </div>

      <!-- Per-action-type breakdown -->
      <ul v-if="actionTypesPresent.length" class="action-type-list">
        <li v-for="[type, count] in actionTypesPresent" :key="type">
          <span class="action-icon" :class="`action-icon-${type}`" :title="actionMeta(type).label">{{ actionMeta(type).icon }}</span>
          <strong>{{ count }}</strong>
          <span class="muted">{{ actionMeta(type).label }}</span>
          <span class="muted" style="font-size:0.85em">— {{ actionMeta(type).hint }}</span>
        </li>
      </ul>
    </section>

    <!-- Action list with view modes -->
    <section v-if="pubActions.length" class="card">
      <div class="card-head">
        <h2>Terms in {{ pub.reference || pub.id }} needing action</h2>
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
            <th v-if="viewMode === 'by-action'">Action</th>
            <th>Term</th>
            <th v-if="viewMode !== 'by-clause'">Clause</th>
            <th v-if="viewMode === 'by-clause'">Clause</th>
            <th>What to decide</th>
          </tr></thead>
          <tbody>
            <tr v-for="r in sortedRows" :key="r.slug + r.type">
              <td v-if="viewMode === 'by-action'">
                <span class="action-icon" :class="`action-icon-${r.type}`" :title="actionMeta(r.type).label">{{ actionMeta(r.type).icon }}</span>
              </td>
              <td class="term-cell"><SLink :to="`/terms/${r.slug}/`">{{ r.name }}</SLink></td>
              <td><code v-if="r.clause !== '—'">{{ r.clause }}</code><span v-else class="muted">—</span></td>
              <td><span class="muted" style="font-size:0.88em">{{ r.description }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Clean terms -->
    <section v-if="cleanTerms.length" class="card">
      <h2>Clean terms in {{ pub.reference || pub.id }} ({{ cleanTerms.length }})</h2>
      <p class="lede">No action needed — these terms match the authoritative baseline.</p>
      <div class="table-scroll">
        <table>
          <thead><tr><th>Term</th><th>VIM</th><th>Clause</th><th>Definition</th></tr></thead>
          <tbody>
            <tr v-for="t in cleanTerms" :key="t.slug">
              <td class="term-cell"><SLink :to="`/terms/${t.slug}/`">{{ t.name }}</SLink></td>
              <td><span :class="['kind', `kind-${t.kind}`]">{{ kindLabel(t.kind) }}</span></td>
              <td><code>{{ pubInstanceForEdition(t)?.clause || '—' }}</code></td>
              <td style="max-width:540px">{{ pubInstanceForEdition(t)?.definition }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </template>
</template>

<style scoped>
.action-type-list {
  list-style: none;
  margin: 1em 0 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.55em;
}
.action-type-list li {
  display: grid;
  grid-template-columns: auto auto 1fr;
  align-items: baseline;
  gap: 0.6em;
  font-size: 0.92rem;
}
.action-type-list li .muted:last-child {
  grid-column: 2 / -1;
  font-size: 0.86em;
}
@media (max-width: 600px) {
  .action-type-list li { grid-template-columns: auto 1fr; }
  .action-type-list li .muted:last-child { grid-column: 1 / -1; }
}
</style>
