<script setup lang="ts">
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import termBySlug from "@/data/term-by-slug.json";
import { useVocabularyEdition } from "@/composables/useVocabularyEdition";

const route = useRoute();
const { label, confidenceClass, isCurrent, isSuperseded, latestLabel, role } = useVocabularyEdition();

const term = computed(() => (termBySlug as any)[route.params.slug as string]);
const enabledEditions = ref<Set<string>>(new Set());
const groupMode = ref(true);

function initEditions() {
  if (term.value?.editions_present) enabledEditions.value = new Set(term.value.editions_present);
}
initEditions();

function toggleEdition(ed: string) {
  if (enabledEditions.value.has(ed)) enabledEditions.value.delete(ed);
  else enabledEditions.value.add(ed);
  enabledEditions.value = new Set(enabledEditions.value);
}

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }

const distinctDefs = computed(() => {
  if (!term.value) return [];
  return Array.from(new Set(term.value.publications.map((p: any) => (p.definition || "").trim()).filter(Boolean)));
});

const consistencyCounts = computed(() => {
  if (!term.value) return { ok: 0, partial: 0, ko: 0, pending: 0 } as Record<string, number>;
  const c: Record<string, number> = { ok: 0, partial: 0, ko: 0, pending: 0 };
  for (const p of term.value.publications) c[p.consistency || "pending"] = (c[p.consistency || "pending"] || 0) + 1;
  return c;
});

const matchStatus = computed(() => {
  if (!term.value) return null;
  if (term.value.kind === "undefined") return { key: "notinviml", label: "Not in VIM/VIML" };
  const urn = term.value.official_concept?.source;
  if (!urn) return { key: "notinviml", label: "Not in VIM/VIML" };
  const r = role(urn);
  if (r === "current") return { key: "full", label: `Full match — ${label(urn)}` };
  if (r) return { key: "outdated", label: `Outdated — ${label(urn)}` };
  return null;
});

const actions = computed(() => {
  if (!term.value) return [];
  const a: any[] = [];
  const oc = term.value.official_concept;
  const lc = term.value.latest_check;
  if (oc && oc.source && isSuperseded(oc.source) && lc) {
    if (lc.found) {
      a.push({ priority: "info", text: `✓ This term IS in ${lc.latest_label} (concept #${lc.concept_id}).`, link: lc.url, label: `View ${lc.latest_label} entry` });
    } else {
      a.push({ priority: "high", text: `✗ This term is NOT in ${lc.latest_label}.` });
    }
  }
  if (term.value.kind === "undefined") {
    a.push({ priority: "high", text: "No authoritative definition in VIM or VIML." });
  }
  if (distinctDefs.value.length > 1) {
    a.push({ priority: "medium", text: `${distinctDefs.value.length} distinct definitions — harmonise.` });
  }
  const cc = consistencyCounts.value;
  if (cc.ko > 0) a.push({ priority: "high", text: `${cc.ko} diverge (ko).` });
  if (cc.partial > 0) a.push({ priority: "low", text: `${cc.partial} partially diverge.` });
  return a;
});

// ── Definition grouping ─────────────────────────────────────────────────
// Group publications by identical definition text so the user can see which
// publications share the same wording (merge candidates) vs which are truly
// unique. Groups are sorted by size (largest first).
type DefGroup = { definition: string; publications: any[]; count: number; editions: string[] };

const definitionGroups = computed<DefGroup[]>(() => {
  if (!term.value) return [];
  const groups = new Map<string, any[]>();
  for (const p of term.value.publications) {
    if (!enabledEditions.value.has(p.edition)) continue;
    const defn = (p.definition || "").trim().replace(/\s+/g, " ");
    const key = defn || "(no definition recorded)";
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(p);
  }
  return Array.from(groups.entries())
    .map(([defn, pubs]) => ({
      definition: defn,
      publications: pubs.sort((a, b) => (b.year || 0) - (a.year || 0)),
      count: pubs.length,
      editions: [...new Set(pubs.map(p => p.edition))],
    }))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return a.definition.localeCompare(b.definition);
    });
});

const sharedGroups = computed(() => definitionGroups.value.filter(g => g.count > 1));
const uniqueGroups = computed(() => definitionGroups.value.filter(g => g.count === 1));

function rowVisible(p: any) {
  return enabledEditions.value.has(p.edition);
}

// Designations: split by type/status for the UI. Falls back to the legacy
// `term.name` as preferred expression when the new field is absent.
const designations = computed(() => (term.value?.designations || []) as any[]);
const preferredExpressionDesignation = computed(() =>
  designations.value.find(d => d.type === "expression" && d.status === "preferred")
);
const preferredExpression = computed(() =>
  (preferredExpressionDesignation.value?.text as string) || (term.value?.name as string) || ""
);
const preferredUsage = computed(() => preferredExpressionDesignation.value?.usage_info as string | undefined);

const admittedExpressions = computed(() =>
  designations.value
    .filter(d => d.type === "expression" && d.status === "admitted")
    .map(d => ({ text: d.text as string, usage: d.usage_info as string | undefined }))
);

// Symbols carry an `international` flag (globally-recognized vs OIML-coined).
const symbolDesignations = computed(() =>
  designations.value
    .filter(d => d.type === "symbol")
    .map(d => ({ text: d.text as string, international: !!d.international }))
);
const symbols = computed(() => symbolDesignations.value.map(s => s.text));

const abbreviations = computed(() =>
  Array.from(new Set(designations.value.filter(d => d.type === "abbreviation").map(d => d.text as string)))
);

// Homonym risk: any designation with usage_info present — flag so editors
// don't merge by text alone.
const hasHomonymRisk = computed(() =>
  designations.value.some(d => d.usage_info && (d.usage_info as string).trim().length > 0)
);

// Provenance analysis: group publication instances by adoption source +
// relationship (identical / modified / authoritative). This answers
// "how many quote VIM verbatim vs modify it vs are OIML-original".
const provenanceGroups = computed(() => {
  const groups = new Map<string, { kind: string; relationship: string; ref: string; label: string; pubs: any[] }>();
  for (const p of term.value?.publications || []) {
    const s = p.source;
    if (!s) {
      const key = `oiml-original|authoritative`;
      const g = groups.get(key) || { kind: "oiml-original", relationship: "authoritative", ref: "", label: "OIML-original", pubs: [] };
      g.pubs.push(p);
      groups.set(key, g);
      continue;
    }
    const label = provenanceLabel(s);
    const key = `${s.kind}|${s.relationship}|${s.ref_source || ""}`;
    const g = groups.get(key) || {
      kind: s.kind,
      relationship: s.relationship,
      ref: s.ref_source ? `${s.ref_source}${s.ref_id ? " §" + s.ref_id : ""}` : "",
      label,
      pubs: [],
    };
    g.pubs.push(p);
    groups.set(key, g);
  }
  // Sort: identical-first (most-convergent first), then by group size desc.
  const rank: Record<string, number> = { identical: 0, modified: 1, authoritative: 2, derived: 3, similar: 4 };
  return Array.from(groups.values()).sort(
    (a, b) => (rank[a.relationship] ?? 9) - (rank[b.relationship] ?? 9) || b.pubs.length - a.pubs.length
  );
});

const modifications = computed(() =>
  (term.value?.publications || [])
    .filter(p => p.source?.modification)
    .map(p => ({ publication: p.publication, edition: p.edition, modification: p.source.modification }))
);

function provenanceLabel(s: any): string {
  if (!s) return "OIML-original";
  const kindLabel = { vim: "VIM", viml: "VIML", oiml_pub: "OIML document", other: "Other" }[s.kind as string] || s.kind;
  return `${kindLabel}${s.ref_source ? ` — ${s.ref_source}` : ""}`;
}

// Examples: merged across all publication instances (deduped by text).
const allExamples = computed(() => {
  const seen = new Set<string>();
  const out: { text: string; citation?: string }[] = [];
  for (const p of term.value?.publications || []) {
    for (const ex of p.examples || []) {
      const text = (ex || "").trim();
      if (!text || seen.has(text)) continue;
      seen.add(text);
      out.push({ text });
    }
  }
  return out;
});
</script>

<template>
  <div v-if="!term" class="card"><p>Term not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/terms/">Terms</SLink> / <span>{{ term.name }}</span></div>
      <h1>{{ term.name }}</h1>
      <p class="lede">
        <span :class="['kind', `kind-${term.kind}`]">{{ kindLabel(term.kind) }}</span>
        <span v-if="matchStatus" :class="['match-status', `match-status-${matchStatus.key}`]">{{ matchStatus.label }}</span>
        G 18 #{{ term.identifier }} · {{ term.publications.length }} instances
      </p>
    </div>

    <section class="card" v-if="term.official_concept && term.kind !== 'undefined'">
      <h2>Authoritative definition</h2>
      <div :class="['authority-defn', confidenceClass(term.official_concept.source)]">
        <span :class="confidenceClass(term.official_concept.source)">
          {{ term.official_concept.edition_label || term.official_concept.source }}
          <span v-if="isCurrent(term.official_concept.source)" class="viml-latest-badge">Latest</span>
        </span>
        · concept <strong>#{{ term.official_concept.id }}</strong>
        <a v-if="term.official_concept.url" class="external" :href="term.official_concept.url">view ↗</a>
        <p v-if="term.official_concept.definition_text" class="authority-defn-body">{{ term.official_concept.definition_text }}</p>
      </div>
      <div v-if="isSuperseded(term.official_concept.source)" class="admonition warn">
        <strong>Outdated:</strong> Cites {{ label(term.official_concept.source) }}. Latest: {{ latestLabel(term.official_concept.source) }}.
      </div>
      <ul v-if="term.related?.length" style="list-style:none;padding:0;margin-top:0.5em">
        <li v-for="(edge, i) in term.related" :key="i" style="margin-bottom:0.3em">
          <span :class="confidenceClass(edge.ref?.source)">{{ edge.ref?.edition_label || edge.ref?.source }}</span>
          · #{{ edge.ref?.id }}
          <div v-if="edge.ref?.definition_text" class="authority-defn-body" style="font-size:0.92em">{{ edge.ref.definition_text }}</div>
        </li>
      </ul>
    </section>

    <section class="card" v-if="designations.length">
      <h2>Designations</h2>
      <dl class="designations">
        <div v-if="preferredExpression" class="designations-row">
          <dt>Term (preferred)</dt>
          <dd>
            {{ preferredExpression }}
            <span v-if="preferredUsage" class="usage-info">[{{ preferredUsage }}]</span>
          </dd>
        </div>
        <template v-for="(ad, i) in admittedExpressions" :key="'ad-'+i">
          <div class="designations-row">
            <dt>Term (admitted)</dt>
            <dd>{{ ad.text }}<span v-if="ad.usage" class="usage-info">[{{ ad.usage }}]</span></dd>
          </div>
        </template>
        <template v-for="(sym, i) in symbolDesignations" :key="'sym-'+i">
          <div class="designations-row">
            <dt>Symbol<span v-if="sym.international" class="intl-pill" title="Internationally recognised">intl</span></dt>
            <dd><code>{{ sym.text }}</code></dd>
          </div>
        </template>
        <div v-if="abbreviations.length" class="designations-row" v-for="abbr in abbreviations" :key="'abbr-'+abbr">
          <dt>Abbreviation</dt>
          <dd><code>{{ abbr }}</code></dd>
        </div>
      </dl>
      <p v-if="hasHomonymRisk" class="admonition warn" style="margin-top:0.6em;margin-bottom:0">
        <strong>Homonym warning:</strong> some designations carry <code>usage_info</code> —
        terms that share the same text but differ in usage are <em>different concepts</em>.
        Do not merge solely on text match.
      </p>
    </section>

    <section class="card" v-if="provenanceGroups.length">
      <h2>Provenance analysis</h2>
      <p class="lede">Where this term's definitions come from. Identical adoptions from the same source can be auto-merged; modified adoptions need TC1 review.</p>
      <table>
        <thead><tr><th>Source</th><th>Relationship</th><th>Publications</th><th>Where</th></tr></thead>
        <tbody>
          <tr v-for="(g, i) in provenanceGroups" :key="i">
            <td><strong>{{ g.label }}</strong><br /><span class="muted">{{ g.ref || '—' }}</span></td>
            <td><span :class="['rel-pill', `rel-${g.relationship}`]">{{ g.relationship }}</span></td>
            <td class="num">{{ g.pubs.length }}</td>
            <td>
              <span v-for="(p, pi) in g.pubs.slice(0, 5)" :key="pi" class="prov-pub">
                <SLink :to="`/publications/${p.publication_id}/`">{{ p.publication }}</SLink>
                <span class="muted"> ({{ p.edition }})</span>
              </span>
              <span v-if="g.pubs.length > 5" class="muted"> +{{ g.pubs.length - 5 }} more</span>
            </td>
          </tr>
        </tbody>
      </table>
      <details v-if="modifications.length" style="margin-top:0.7em">
        <summary>Modification notes ({{ modifications.length }})</summary>
        <ul style="margin:0.5em 0 0;padding-left:1.2em;font-size:0.9em">
          <li v-for="(m, i) in modifications" :key="i" style="margin-bottom:0.4em">
            <strong>{{ m.publication }}</strong> <span class="muted">({{ m.edition }})</span>: {{ m.modification }}
          </li>
        </ul>
      </details>
    </section>

    <section class="card" v-if="allExamples.length">
      <h2>Examples</h2>
      <ul class="examples-list">
        <li v-for="(ex, i) in allExamples" :key="i">{{ ex.text }}<span class="muted" v-if="ex.citation"> — {{ ex.citation }}</span></li>
      </ul>
    </section>

    <section v-if="actions.length" class="card">
      <h2>Suggested actions</h2>
      <ol class="actions-list">
        <li v-for="(a, i) in actions" :key="i">
          <span :class="['action-pill', `action-pill-${a.priority}`]">{{ a.priority.toUpperCase() }}</span>
          {{ a.text }}
          <a v-if="a.link" :href="a.link"> {{ a.label }}</a>
        </li>
      </ol>
    </section>

    <section class="card">
      <div class="card-head">
        <h2>Publication instances</h2>
        <div style="display:flex;gap:1em;align-items:center;flex-wrap:wrap">
          <label><input type="checkbox" v-model="groupMode" /> Group identical</label>
          <span v-for="ed in term.editions_present" :key="ed">
            <label><input type="checkbox" :checked="enabledEditions.has(ed)" @change="toggleEdition(ed)" />
              <span :class="['edition-pill', `edition-${ed.toLowerCase()}`]">{{ ed }}</span>
            </label>
          </span>
        </div>
      </div>

      <!-- Grouped mode: show definition groups -->
      <template v-if="groupMode">
        <p class="lede" style="margin-bottom:0.5em">
          <strong>{{ definitionGroups.length }}</strong> distinct definitions across
          <strong>{{ definitionGroups.reduce((s, g) => s + g.count, 0) }}</strong> publications.
          <span v-if="sharedGroups.length">{{ sharedGroups.length }} definitions are shared by multiple publications (merge candidates).</span>
        </p>

        <!-- Shared definition groups (count > 1) -->
        <div v-for="(g, i) in sharedGroups" :key="i" class="def-group">
          <div class="def-group-head">
            <span class="def-group-badge">{{ g.count }} identical</span>
            <span v-for="ed in g.editions" :key="ed" :class="['edition-pill', `edition-${ed.toLowerCase()}`]">{{ ed }}</span>
          </div>
          <div class="def-group-text">{{ g.definition }}</div>
          <table class="def-group-pubs">
            <thead><tr><th>Ed.</th><th>Year</th><th>Publication</th><th>Clause</th><th>G 18 #</th><th>Consistency</th></tr></thead>
            <tbody>
              <tr v-for="p in g.publications" :key="p.g18_entry">
                <td><span :class="['edition-pill', `edition-${p.edition?.toLowerCase()}`]">{{ p.edition }}</span></td>
                <td class="num">{{ p.year }}</td>
                <td><SLink :to="`/publications/${p.publication_id}/`">{{ p.publication }}</SLink></td>
                <td class="num">{{ p.clause }}</td>
                <td class="num">{{ p.g18_entry }}</td>
                <td><span :class="['badge', `badge-${p.consistency || 'pending'}`]">{{ p.consistency || "pending" }}</span></td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Unique definitions (count === 1) -->
        <div v-if="uniqueGroups.length" class="def-group-unique-section">
          <h3>{{ uniqueGroups.length }} unique definition{{ uniqueGroups.length === 1 ? '' : 's' }} (each used by only one publication)</h3>
          <table>
            <thead><tr><th>Ed.</th><th>Year</th><th>Publication</th><th>Clause</th><th>G 18 #</th><th>Definition</th><th></th></tr></thead>
            <tbody>
              <tr v-for="g in uniqueGroups" :key="g.publications[0].g18_entry" class="row-divergent">
                <td><span :class="['edition-pill', `edition-${g.publications[0].edition?.toLowerCase()}`]">{{ g.publications[0].edition }}</span></td>
                <td class="num">{{ g.publications[0].year }}</td>
                <td><SLink :to="`/publications/${g.publications[0].publication_id}/`">{{ g.publications[0].publication }}</SLink></td>
                <td class="num">{{ g.publications[0].clause }}</td>
                <td class="num">{{ g.publications[0].g18_entry }}</td>
                <td style="max-width:400px"><div style="white-space:pre-wrap;font-size:0.9em">{{ g.definition }}</div></td>
                <td><span :class="['badge', `badge-${g.publications[0].consistency || 'pending'}`]">{{ g.publications[0].consistency || "pending" }}</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>

      <!-- Flat mode: original table -->
      <template v-else>
        <table>
          <thead><tr><th>Ed.</th><th>Year</th><th>Publication</th><th>Clause</th><th>G 18 #</th><th>Definition</th><th>Notes</th><th>Examples</th><th>Source</th><th>Consistency</th></tr></thead>
          <tbody>
            <tr v-for="p in term.publications" :key="p.g18_entry" v-show="rowVisible(p)" :class="{ 'row-divergent': distinctDefs.length > 1 && p.definition?.trim() !== distinctDefs[0], 'row-modified': p.source?.relationship === 'modified' }">
              <td><span :class="['edition-pill', `edition-${p.edition?.toLowerCase()}`]">{{ p.edition }}</span></td>
              <td class="num">{{ p.year }}</td>
              <td><SLink :to="`/publications/${p.publication_id}/`">{{ p.publication }}</SLink></td>
              <td class="num">{{ p.clause }}</td>
              <td class="num"><code>{{ p.g18_entry }}</code></td>
              <td style="max-width:540px"><div style="white-space:pre-wrap">{{ p.definition }}</div></td>
              <td v-if="(p.notes || []).length" style="max-width:320px"><ul class="inline-notes"><li v-for="(n, ni) in p.notes" :key="ni">{{ n }}</li></ul></td>
              <td v-else class="muted">—</td>
              <td v-if="(p.examples || []).length" style="max-width:320px"><ul class="inline-notes"><li v-for="(x, xi) in p.examples" :key="xi">{{ x }}</li></ul></td>
              <td v-else class="muted">—</td>
              <td>
                <span v-if="p.source" :class="['rel-pill', `rel-${p.source.relationship}`]" :title="p.source.modification || ''">
                  {{ p.source.relationship }}
                </span>
                <span v-else class="muted">OIML</span>
              </td>
              <td><span :class="['badge', `badge-${p.consistency || 'pending'}`]">{{ p.consistency || "pending" }}</span></td>
            </tr>
          </tbody>
        </table>
      </template>
    </section>
  </template>
</template>

<style scoped>
.def-group {
  border: 1px solid var(--rule);
  border-radius: 5px;
  margin: 0.8em 0;
  overflow: hidden;
}
.def-group-head {
  display: flex;
  align-items: center;
  gap: 0.5em;
  padding: 0.5em 0.8em;
  background: #f0f7ff;
  border-bottom: 1px solid var(--rule);
}
.def-group-badge {
  display: inline-block;
  padding: 0.1em 0.5em;
  border-radius: 3px;
  background: var(--oiml-brand-600);
  color: #fff;
  font-size: 0.78em;
  font-weight: 700;
}
.def-group-text {
  padding: 0.6em 0.8em;
  font-size: 0.92em;
  line-height: 1.4;
  white-space: pre-wrap;
  background: #fafbfc;
  border-bottom: 1px solid var(--rule);
}
.def-group-pubs {
  font-size: 0.88em;
}
.def-group-pubs th { font-size: 0.78em; }
.def-group-unique-section {
  margin-top: 1.2em;
}
.def-group-unique-section h3 {
  font-size: 0.95em;
  color: var(--oiml-amber-deep);
  margin-bottom: 0.4em;
}
.designations {
  margin: 0;
  display: grid;
  grid-template-columns: max-content 1fr;
  gap: 0.4em 1.2em;
  align-items: baseline;
}
.designations-row {
  display: contents;
}
.designations dt {
  font-weight: 600;
  color: var(--ink-soft);
  font-size: 0.88em;
}
.designations dd {
  margin: 0;
}
@media (max-width: 600px) {
  .designations { grid-template-columns: 1fr; gap: 0.1em 0; }
  .designations dt { font-size: 0.78em; text-transform: uppercase; letter-spacing: 0.04em; margin-top: 0.4em; }
}
.examples-list { margin: 0; padding-left: 1.2em; }
.examples-list li { padding: 0.25em 0; line-height: 1.45; }
.inline-notes { margin: 0; padding-left: 1.1em; }
.inline-notes li { padding: 0.15em 0; font-size: 0.88em; line-height: 1.4; }

.usage-info {
  display: inline-block;
  margin-left: 0.4em;
  padding: 0.05em 0.45em;
  background: #fef3c7;
  color: var(--oiml-amber-deep);
  border-radius: 3px;
  font-size: 0.78em;
  font-style: italic;
}
.intl-pill {
  display: inline-block;
  margin-left: 0.4em;
  padding: 0.05em 0.4em;
  background: #dcfce7;
  color: var(--green);
  border-radius: 3px;
  font-size: 0.7em;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.rel-pill {
  display: inline-block;
  padding: 0.1em 0.5em;
  border-radius: 3px;
  font-size: 0.78em;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.rel-identical { background: #dcfce7; color: var(--green); }
.rel-modified  { background: #fef3c7; color: var(--oiml-amber-deep); }
.rel-authoritative { background: #dbeafe; color: #1e3a8a; }
.rel-derived   { background: #fef3c7; color: var(--oiml-amber-deep); }
.rel-similar   { background: #eef0f3; color: var(--ink-muted); }
.prov-pub { display: inline-block; margin-right: 0.6em; }
.row-modified { background: #fffbeb !important; }
</style>
