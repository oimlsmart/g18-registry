<script setup lang="ts">
import { computed, ref } from "vue";
import { useJsonFetch } from "@/composables/useJsonFetch";
import { useVocabularyEdition } from "@/composables/useVocabularyEdition";
import { useConceptVersions } from "@/composables/useConceptVersions";
import { isOimlSpecific } from "@/utils/edition-utils";
import SLink from "@/components/SLink.vue";
import DefText from "@/components/DefText.vue";
import ConceptBody from "@/components/ConceptBody.vue";
import ConceptDiffView from "@/components/ConceptDiffView.vue";
import DecisionFlowSVG from "@/components/DecisionFlowSVG.vue";
import { kindLabel, normalizeDef, isHistoricTerm, groupProvenance, provenanceLabel as provLabel, slugify } from "@/utils/term-utils";

const props = defineProps<{ slug: string }>();
const base = import.meta.env.BASE_URL;
const { label, confidenceClass, isCurrent, isSuperseded, latestLabel, role, vocabUrl } = useVocabularyEdition();

const { data: term, loading } = useJsonFetch(() => `${base}data/terms/${props.slug}.json`);

// Withdrawn publications: detect if any publication instance is withdrawn.
// These concepts should be retired from G 18:current and G 18:202X.
const withdrawnPubs = computed(() => {
  const pubs = term.value?.publications || [];
  return pubs.filter((p: any) => p.withdrawn);
});

// Sourcing publications — which OIML documents define this term
const sourcingPublications = computed(() => {
  const pubs = [...new Set((term.value?.publications || []).map((p: any) => p.publication_id))];
  return pubs.slice(0, 6);
});
const sourcingPublicationsCount = computed(() =>
  new Set((term.value?.publications || []).map((p: any) => p.publication_id)).size
);

// Sourced from — where this concept was adopted from (V 1/V 2, OIML pub, ISO, etc.)
const sourcedFromSources = computed(() => {
  const sources = new Map<string, number>();
  for (const p of (term.value?.publications || [])) {
    for (const sf of (p.sourced_from || [])) {
      const src = sf.source as string;
      if (src) sources.set(src, (sources.get(src) || 0) + 1);
    }
  }
  return [...sources.entries()].sort((a, b) => b[1] - a[1]).map(([src]) => src);
});
function classifySource(src: string): { type: string; label: string } {
  if (src.match(/OIML V [12]/) || src.match(/^VIM/)) return { type: "vocab", label: "V 1/V 2" };
  if (src.match(/^OIML [RDB]/)) return { type: "oiml", label: "OIML publication" };
  if (src.match(/^ISO/) || src.match(/^IEC/)) return { type: "external", label: "external standard" };
  return { type: "other", label: "other source" };
}

// Near-miss data now comes from term.vocab_presence (fetched per-term)

// Publication citation status: for each publication instance, what VIM/VIML
// edition does it cite? This directly answers the user's Step 1 question:
// "Is this recommendation term adopting it from VIM/VIML?"
interface PubCitation {
  pubId: string;
  editions: string[];
  refSource: string | null;
  refId: string | null;
  status: "current" | "outdated" | "no-citation";
  formattedRef: string;
}
const pubCitations = computed<PubCitation[]>(() => {
  const pubs = (term.value?.publications || []);
  const byPub = new Map<string, PubCitation>();
  for (const p of pubs) {
    const pid = p.publication_id;
    if (!pid) continue;
    if (!byPub.has(pid)) {
      const src = p.source;
      const refSource = src?.ref_source || null;
      const refId = src?.ref_id || null;
      let status: PubCitation["status"] = "no-citation";
      let formattedRef = "No VIM/VIML citation";
      if (refSource) {
        const m = refSource.match(/V\s*(\d)-\d+:(\d{4})/);
        if (m) {
          const vocabName = m[1] === "1" ? "VIML" : "VIM";
          formattedRef = `${vocabName} ${m[2]}${refId ? ` §${refId}` : ""}`;
          const urn = vocabName === "VIM" ? "urn:oiml:pub:v:2:" : "urn:oiml:pub:v:1:";
          status = isCurrent(urn + m[2]) ? "current" : "outdated";
        } else {
          formattedRef = refSource;
          status = "outdated";
        }
      }
      byPub.set(pid, { pubId: pid, editions: [], refSource, refId, status, formattedRef });
    }
    if (p.edition) byPub.get(pid)!.editions.push(p.edition);
  }
  return [...byPub.values()].sort((a, b) => {
    const rank = { current: 0, outdated: 1, "no-citation": 2 };
    return (rank[a.status] - rank[b.status]) || (a.pubId || "").localeCompare(b.pubId || "");
  });
});
const citationSummary = computed(() => {
  const cs = pubCitations.value;
  const current = cs.filter(c => c.status === "current").length;
  const outdated = cs.filter(c => c.status === "outdated").length;
  const noCite = cs.filter(c => c.status === "no-citation").length;
  return { current, outdated, noCite, total: cs.length };
});

// Top-level recommendation banner — summarizes what TC 1 should do
const recommendation = computed(() => {
  const t = term.value;
  if (!t) return { level: "none", icon: "", text: "", link: null, action: "" };

  if (canPropose.value) {
    if (term.value?.vocab_presence?.vim || term.value?.vocab_presence?.viml) {
      return {
        level: "info", icon: "📋",
        text: `Not in V 1/V 2. Resembles a VIM/VIML term — consider adopting it or proposing for V 3.`,
        link: `${base}proposals/?term=${t.slug}`, action: "Propose",
      };
    }
    return {
      level: "info", icon: "📝",
      text: `Not in V 1/V 2. No near-miss found — consider proposing for V 3.`,
      link: `${base}proposals/?term=${t.slug}`, action: "Propose",
    };
  }

  const oc = t.official_concept;
  if (oc?.source && isCurrent(oc.source)) {
    return { level: "ok", icon: "✅", text: "Citation is up to date. No actions needed.", link: null, action: "" };
  }

  if (t.latest_check?.found) {
    return {
      level: "warn", icon: "⚠️",
      text: `Citation is outdated. Update to ${t.latest_check.latest_label}.`,
      link: t.latest_check.url || null, action: "View concept",
    };
  }

  if (t.latest_check && !t.latest_check.found) {
    return {
      level: "warn", icon: "📝",
      text: `Removed from ${t.latest_check.latest_label}. Propose for V 1, V 2, or V 3.`,
      link: `${base}proposals/?term=${t.slug}`, action: "Propose",
    };
  }

  return { level: "none", icon: "", text: "", link: null, action: "" };
});


const g18Definition = computed(() => operativeDefinition.value?.text || "");
const vimDefinition = computed(() => term.value?.official_concept?.definition_text || "");
const hasDefDivergence = computed(() => {
  if (!g18Definition.value || !vimDefinition.value) return false;
  const norm = (s: string) => s.replace(/\{\{[^}]+\}\}/g, "").replace(/\s+/g, " ").trim().toLowerCase();
  return norm(g18Definition.value) !== norm(vimDefinition.value);
});

// Edition filter removed — the concept detail page shows ALL publication
// instances regardless of G 18 edition. G 18 entry IDs appear as
// metadata chips on each instance, not as a top-level filter.

const enabledEditions = computed(() => {
  const eds = term.value?.editions_present || [];
  return new Set(eds);
});
const groupMode = ref(true);

function editionCount(ed: string): number {
  return (term.value?.publications || []).filter(p => p.edition === ed).length;
}


const distinctDefs = computed(() => {
  if (!term.value) return [];
  return Array.from(new Set(term.value.publications.map((p: any) => normalizeDef(p.definition || "")).filter(Boolean)));
});

// Per-edition distinct-definition counts. Cross-edition definition changes
// are intentional editorial evolution (TC 1 rewords between 2010 and 202X)
// and are NOT conflicts. True harmonisation divergence is WITHIN an edition.
const distinctDefsByEdition = computed<Record<string, string[]>>(() => {
  if (!term.value) return {};
  const byEd: Record<string, Set<string>> = {};
  for (const p of term.value.publications) {
    const ed = p.edition || "(unspecified)";
    const d = normalizeDef(p.definition || "");
    if (!d) continue;
    if (!byEd[ed]) byEd[ed] = new Set();
    byEd[ed].add(d);
  }
  const out: Record<string, string[]> = {};
  for (const [ed, set] of Object.entries(byEd)) out[ed] = Array.from(set);
  return out;
});

// The "harmonise problem" magnitude: max distinct-defs count within any
// single edition. 1 = consistent within each edition.
const worstEditionDistinctCount = computed(() =>
  Math.max(0, ...Object.values(distinctDefsByEdition.value).map(s => s.length))
);
const worstEdition = computed(() => {
  let worst = "";
  let max = 0;
  for (const [ed, defs] of Object.entries(distinctDefsByEdition.value)) {
    if (defs.length > max) { max = defs.length; worst = ed; }
  }
  return worst;
});

const CONSISTENCY_HINTS: Record<string, string> = {
  ok: "Definition matches the authoritative VIM/VIML source",
  partial: "Partial match — some wording divergence",
  ko: "Significant divergence from the authoritative definition",
  pending: "Not yet classified — LLM consistency check pending",
};
function consistencyHint(c: string): string { return CONSISTENCY_HINTS[c] || c; }

const consistencyCounts = computed(() => {
  if (!term.value) return { ok: 0, partial: 0, ko: 0, pending: 0 } as Record<string, number>;
  const c: Record<string, number> = { ok: 0, partial: 0, ko: 0, pending: 0 };
  for (const p of term.value.publications) c[p.consistency || "pending"] = (c[p.consistency || "pending"] || 0) + 1;
  return c;
});

const matchStatus = computed(() => {
  if (!term.value) return null;
  if (isOimlSpecific(term.value.kind)) return { key: "notinviml", label: "Not in VIM/VIML" };
  const urn = term.value.official_concept?.source;
  if (!urn) return { key: "notinviml", label: "Not in VIM/VIML" };
  const r = role(urn);
  if (r === "current") return { key: "full", label: `Full match — ${label(urn)}` };
  if (r) return { key: "outdated", label: `Outdated — ${label(urn)}` };
  return null;
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
    const defn = normalizeDef(p.definition || "").replace(/\s+/g, " ");
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

// Are consistency badges actually meaningful here? When every instance is
// "pending" (LLM classification not yet cached), showing the column is
// pure noise. Hide it in that case.
const hasConsistencyData = computed(() => {
  if (!term.value) return false;
  return (term.value.publications || []).some((p: any) => p.consistency && p.consistency !== "pending");
});

// Historic-only: term exists only in the 2010 edition. TC 1 cannot act.
const isHistoricTermComputed = computed(() => isHistoricTerm(term.value));

// Concept version engine: state, versions, actions, see-also — all
// extracted to useConceptVersions for testability and locality.
const {
  fullConceptLang, fullConceptLangs, conceptData,
  conceptState, showConceptCard, canPropose,
  conceptVersions, conceptActions, seeAlso,
} = useConceptVersions(term, worstEditionDistinctCount);

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

// Operative definition: when a term has no authoritative VIM/VIML source
// (kind === 'undefined'), surface the wording used by the publications so
// the page leads with a definition instead of burying it inside the
// Publication instances table. Picks the most-cited wording; ties broken
// by lexicographic order for stability.
const operativeDefinition = computed<{ text: string; pubCount: number; distinctCount: number; editions: string[] } | null>(() => {
  if (!term.value) return null;
  if (term.value.official_concept && !isOimlSpecific(term.value.kind)) return null;
  const counts = new Map<string, { pubs: any[]; editions: Set<string> }>();
  for (const p of term.value.publications || []) {
    const d = normalizeDef(p.definition || "");
    if (!d) continue;
    if (!counts.has(d)) counts.set(d, { pubs: [], editions: new Set() });
    const entry = counts.get(d)!;
    entry.pubs.push(p);
    if (p.edition) entry.editions.add(p.edition);
  }
  if (!counts.size) return null;
  // most-cited wording
  let best: { text: string; pubs: any[]; editions: Set<string> } | null = null;
  for (const [text, entry] of counts.entries()) {
    if (!best || entry.pubs.length > best.pubs.length) best = { text, pubs: entry.pubs, editions: entry.editions };
  }
  if (!best) return null;
  return {
    text: best.text,
    pubCount: best.pubs.length,
    distinctCount: counts.size,
    editions: Array.from(best.editions).sort(),
  };
});

// Homonym risk: any designation with usage_info present — flag so editors
// don't merge by text alone.
const hasHomonymRisk = computed(() =>
  designations.value.some(d => d.usage_info && (d.usage_info as string).trim().length > 0)
);

// Provenance analysis: group publication instances by adoption source.
const provenanceGroups = computed(() => groupProvenance(term.value?.publications || []));

const modifications = computed(() =>
  (term.value?.publications || [])
    .filter(p => p.source?.modification)
    .map(p => ({ publication: p.publication, edition: p.edition, modification: p.source.modification }))
);

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

// Authoritative baseline text for match comparison. From the official
// concept (VIM/VIML citation).
const authoritativeText = computed(() => {
  const oc = term.value?.official_concept;
  return oc?.definition_text ? (oc.definition_text as string).trim() : "";
});

// Per-publication match status vs authoritative: matches / modified / differs / no-baseline.
function pubMatchStatus(p: any): { key: string; label: string } {
  if (!authoritativeText.value) return { key: "nobaseline", label: "no baseline" };
  const def = normalizeDef(p.definition || "");
  if (!def) return { key: "empty", label: "—" };
  if (def === normalizeDef(authoritativeText.value)) return { key: "match", label: "matches VIM" };
  if (p.source?.relationship === "modified") return { key: "modified", label: "modified" };
  return { key: "differs", label: "differs" };
}

// All annotations across all publication instances (deduped).
const allAnnotations = computed(() => {
  const seen = new Set<string>();
  const out: { text: string; type: string }[] = [];
  for (const p of term.value?.publications || []) {
    for (const ann of (p as any).source_lineage?.annotations || []) {
      const text = (ann.text || "").trim();
      if (!text || seen.has(text)) continue;
      seen.add(text);
      out.push({ text, type: ann.type || "note" });
    }
  }
  return out;
});

// Check if any publication has multi-source paragraphs (where one
// paragraph cites 2+ sources — complex lineage).
const hasMultiSourceParagraphs = computed(() =>
  (term.value?.publications || []).some((p: any) =>
    (p.source_lineage?.paragraph_sources || []).some((ps: any) => (ps.sources || []).length > 1)
  )
);

// TC/SC filter for the publication instances table.
const allTCs = computed(() => {
  const set = new Set<string>();
  for (const p of term.value?.publications || []) {
    if (p.tc_sc?.trim()) set.add(p.tc_sc);
  }
  return Array.from(set).sort();
});
const onlyTC = ref("");
const filteredPublications = computed(() => {
  if (!onlyTC.value) return term.value?.publications || [];
  return (term.value?.publications || []).filter(p => p.tc_sc === onlyTC.value);
});
</script>

<template>
  <div v-if="loading" class="card"><p style="color: var(--color-ink-muted)">Loading…</p></div>
  <div v-else-if="!term" class="card"><p>Term not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/concepts/">Terms</SLink> / <span><DefText :text="term.name" /></span></div>
      <h1><DefText :text="term.name" /></h1>
      <div class="term-meta-row">
        <span :class="['kind', `kind-${term.kind}`]">{{ kindLabel(term.kind) }}</span>
        <span v-if="matchStatus" :class="['match-status', `match-status-${matchStatus.key}`]">{{ matchStatus.label }}</span>
        <span class="g18-chip" title="G 18 entry number">G 18 #{{ term.identifier }}</span>
      </div>
      <!-- Originating documents: prominently show which OIML publications use this term -->
      <div class="sourcing-docs">
        <span class="sourcing-label">From</span>
        <SLink v-for="p in sourcingPublications" :key="p"
               :to="`/publications/${slugify(p)}/`" class="sourcing-doc">{{ p }}</SLink>
        <span v-if="sourcingPublicationsCount > 6" class="sourcing-more">
          +{{ sourcingPublicationsCount - 6 }} more
        </span>
      </div>
      <!-- Sourced from: where this concept was adopted from -->
      <div v-if="sourcedFromSources.length" class="sourced-from">
        <span class="sourced-from-label">Sourced from</span>
        <span v-for="src in sourcedFromSources.slice(0, 6)" :key="src"
              :class="['sourced-from-chip', `sf-${classifySource(src).type}`]"
              :title="classifySource(src).label">
          {{ src }}
        </span>
        <span v-if="sourcedFromSources.length > 6" class="sourcing-more">
          +{{ sourcedFromSources.length - 6 }} more
        </span>
      </div>
    </div>

    <!-- Recommendations banner: appears at the top, summarizes what TC 1 should do -->
    <div :class="['recommendations-banner', `rec-${recommendation.level}`]">
      <span class="rec-icon">{{ recommendation.icon }}</span>
      <div class="rec-body">
        <div class="rec-label">Recommendation</div>
        <div class="rec-text">{{ recommendation.text }}</div>
      </div>
      <a v-if="recommendation.link" class="rec-action" :href="recommendation.link">{{ recommendation.action }} →</a>
    </div>

    <!-- Withdrawn publication warning: concept cited in a withdrawn OIML pub -->
    <div v-if="withdrawnPubs.length" class="withdrawn-warning">
      <span class="withdrawn-warning-icon">⚠</span>
      <div class="withdrawn-warning-body">
        <div class="withdrawn-warning-text">
          Cited in withdrawn OIML publication(s):
          <span v-for="(p, i) in [...new Set(withdrawnPubs.map(p => p.publication_id))]" :key="p" class="withdrawn-pub-id">
            <SLink :to="`/publications/${slugify(p)}/`">{{ p }}</SLink><span v-if="i < [...new Set(withdrawnPubs.map(pp => pp.publication_id))].length - 1">, </span>
          </span>
        </div>
        <div class="withdrawn-warning-action">Action: Retire from G 18:current and G 18:202X</div>
      </div>
    </div>
    <section class="card citation-status-card" v-if="pubCitations.length">
      <div class="card-head">
        <h2>Publication citations</h2>
        <span class="citation-summary">
          <span class="citation-count citation-count-current">{{ citationSummary.current }} current</span>
          <span v-if="citationSummary.outdated" class="citation-count citation-count-outdated">{{ citationSummary.outdated }} outdated</span>
          <span v-if="citationSummary.noCite" class="citation-count citation-count-nocite">{{ citationSummary.noCite }} no citation</span>
        </span>
      </div>
      <div class="citation-list">
        <div v-for="c in pubCitations" :key="c.pubId" :class="['citation-row', `citation-row-${c.status}`]">
          <SLink :to="`/publications/${slugify(c.pubId)}/`" class="citation-pub">{{ c.pubId }}</SLink>
          <span v-for="e in c.editions" :key="e" :class="['edition-pill', `edition-${e.toLowerCase()}`]">{{ e === 'complete' ? 'OIML' : e }}</span>
          <span class="citation-arrow">→</span>
          <span :class="['citation-ref', `citation-ref-${c.status}`]">{{ c.formattedRef }}</span>
          <span v-if="c.status === 'current'" class="citation-action citation-action-ok">up to date</span>
          <span v-else-if="c.status === 'outdated'" class="citation-action citation-action-warn">update citation</span>
          <span v-else class="citation-action citation-action-info">OIML-original</span>
        </div>
      </div>
    </section>

    <!-- Historic-only callout: term exists only in 2010. TC 1 cannot act. -->
    <section v-if="isHistoricTermComputed" class="card admonition" style="background: var(--color-paper-tint); border-color: var(--color-rule);">
      <strong>Historic (2010 only).</strong>
      This term appears only in the published G 18:2010 edition. TC 1 cannot
      take action on it — 2010 is frozen. Shown in worklists for completeness,
      visually deprioritized.
    </section>

    <!-- G 18 edition filter removed: concept detail shows all instances.
         G 18 entry IDs appear as metadata chips on each publication row. -->

    <section class="card" v-if="showConceptCard || canPropose">
      <!-- DECISION FLOW: visual tree + recommendation -->
      <div class="decision-box">
        <h2>Decision flow</h2>
        <DecisionFlowSVG
          :kind="term.kind"
          :is-current="!!(term.official_concept?.source && isCurrent(term.official_concept.source))"
          :is-superseded="!!(term.official_concept?.source && isSuperseded(term.official_concept.source))"
          :latest-check-found="term.latest_check?.found ?? null"
          :has-near-miss="!!(term?.vocab_presence?.vim || term?.vocab_presence?.viml)"
          :has-withdrawn="withdrawnPubs.length > 0"
        />
        <div class="decision-recommendation">
          <div v-if="canPropose" class="decision-path">
            <strong>Not in VIM/VIML.</strong>
            <template v-if="term?.vocab_presence?.vim || term?.vocab_presence?.viml">
              This term resembles:
              <div class="near-miss-list">
                <a v-if="term.vocab_presence.viml" :href="term.vocab_presence.viml.url" class="near-miss-item" target="_blank" rel="noopener">
                  <span class="near-miss-vocab">VIML</span>
                  {{ term.vocab_presence.viml.designation }}
                  <span v-if="term.vocab_presence.viml.similarity" class="near-miss-sim">{{ term.vocab_presence.viml.similarity }}</span>
                </a>
                <a v-if="term.vocab_presence.vim" :href="term.vocab_presence.vim.url" class="near-miss-item" target="_blank" rel="noopener">
                  <span class="near-miss-vocab">VIM</span>
                  {{ term.vocab_presence.vim.designation }}
                  <span v-if="term.vocab_presence.vim.similarity" class="near-miss-sim">{{ term.vocab_presence.vim.similarity }}</span>
                </a>
              </div>
              <div class="decision-options">
                <a v-if="term.vocab_presence.viml" class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Adopt V 1 (VIML: {{ term.vocab_presence.viml.designation }}) →</a>
                <a v-if="term.vocab_presence.vim" class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Adopt V 2 (VIM: {{ term.vocab_presence.vim.designation }}) →</a>
                <a class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Propose V 3 →</a>
              </div>
            </template>
            <template v-else>
              No VIM/VIML near-miss found — this appears to be a unique OIML term.
              <div class="decision-options">
                <a class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Propose for V 3 →</a>
              </div>
            </template>
          </div>
          <div v-else-if="term.official_concept?.source && isCurrent(term.official_concept.source)" class="decision-path decision-path-ok">
            <strong>Citation is up to date.</strong> Nothing to do — this term cites the latest VIM/VIML edition.
          </div>
          <div v-else-if="term.latest_check?.found" class="decision-path">
            <strong>Citation is outdated.</strong> The term exists in {{ term.latest_check?.latest_label }} but publications cite an older edition.
            <div class="decision-options">
              <a v-if="term.latest_check?.url" class="decision-option" :href="term.latest_check.url">View {{ term.latest_check?.latest_label }} concept ↗</a>
              <a class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Propose →</a>
            </div>
          </div>
          <div v-else-if="term.latest_check && !term.latest_check.found" class="decision-path">
            <strong>Removed from {{ term.latest_check?.latest_label }}.</strong> This term is no longer in the latest VIM/VIML edition.
            <div class="decision-options">
              <a class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Propose for V 1 (VIML) →</a>
              <a class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Propose for V 2 (VIM) →</a>
              <a class="decision-option" :href="`${base}proposals/?term=${term.slug}`">Propose for V 3 →</a>
            </div>
          </div>
        </div>
      </div>

      <!-- VIM/VIML concept comparison: full concept content for OIML-original terms with near-miss -->
      <div v-if="term.vocab_presence?.viml || term.vocab_presence?.vim" class="vocab-concept-comparison">
        <div class="vocab-concept-comparison-head">V 1/V 2 concept — compare before proposing</div>
        <div class="vocab-concept-grid">
          <div v-if="term.vocab_presence?.viml" class="vocab-concept-card vocab-concept-viml">
            <div class="vocab-concept-badge">V 1 — {{ term.vocab_presence.viml.latest_label }}</div>
            <div class="vocab-concept-designation">{{ term.vocab_presence.viml.designation }}</div>
            <div v-if="term.vocab_presence.viml.designations?.filter(d => d.status === 'admitted').length" class="vocab-concept-admitted">
              <span class="muted">also: </span>
              <span v-for="(d, i) in term.vocab_presence.viml.designations.filter(d => d.status === 'admitted')" :key="i">
                <span v-if="d.usage_info" class="vocab-usage">{{ d.usage_info }} </span>{{ d.text }}<span v-if="i < term.vocab_presence.viml.designations.filter(d => d.status === 'admitted').length - 1">, </span>
              </span>
            </div>
            <DefText v-if="term.vocab_presence.viml.definition" :text="term.vocab_presence.viml.definition" class="vocab-concept-def" />
            <div v-if="term.vocab_presence.viml.notes?.length" class="vocab-concept-notes">
              <div v-for="(n, i) in term.vocab_presence.viml.notes" :key="i" class="vocab-note"><DefText :text="n" /></div>
            </div>
            <div v-if="term.vocab_presence.viml.examples?.length" class="vocab-concept-examples">
              <div v-for="(e, i) in term.vocab_presence.viml.examples" :key="i" class="vocab-example"><em>EXAMPLE:</em> <DefText :text="e" /></div>
            </div>
            <a :href="term.vocab_presence.viml.url" class="vocab-concept-link" target="_blank" rel="noopener">View full concept ↗</a>
          </div>
          <div v-if="term.vocab_presence?.vim" class="vocab-concept-card vocab-concept-vim">
            <div class="vocab-concept-badge">V 2 — {{ term.vocab_presence.vim.latest_label }}</div>
            <div class="vocab-concept-designation">{{ term.vocab_presence.vim.designation }}</div>
            <div v-if="term.vocab_presence.vim.designations?.filter(d => d.status === 'admitted').length" class="vocab-concept-admitted">
              <span class="muted">also: </span>
              <span v-for="(d, i) in term.vocab_presence.vim.designations.filter(d => d.status === 'admitted')" :key="i">
                <span v-if="d.usage_info" class="vocab-usage">{{ d.usage_info }} </span>{{ d.text }}<span v-if="i < term.vocab_presence.vim.designations.filter(d => d.status === 'admitted').length - 1">, </span>
              </span>
            </div>
            <DefText v-if="term.vocab_presence.vim.definition" :text="term.vocab_presence.vim.definition" class="vocab-concept-def" />
            <div v-if="term.vocab_presence.vim.notes?.length" class="vocab-concept-notes">
              <div v-for="(n, i) in term.vocab_presence.vim.notes" :key="i" class="vocab-note"><DefText :text="n" /></div>
            </div>
            <div v-if="term.vocab_presence.vim.examples?.length" class="vocab-concept-examples">
              <div v-for="(e, i) in term.vocab_presence.vim.examples" :key="i" class="vocab-example"><em>EXAMPLE:</em> <DefText :text="e" /></div>
            </div>
            <a :href="term.vocab_presence.vim.url" class="vocab-concept-link" target="_blank" rel="noopener">View full concept ↗</a>
          </div>
        </div>
      </div>

      <!-- Definition comparison: G 18 usage vs VIM/VIML authoritative -->
      <div v-if="hasDefDivergence" class="defn-comparison">
        <div class="defn-comparison-head">Definition comparison</div>
        <div class="defn-comparison-grid">
          <div class="defn-comparison-col">
            <span class="defn-comparison-label">G 18 (from publications)</span>
            <p class="defn-comparison-text"><DefText :text="g18Definition" /></p>
          </div>
          <div class="defn-comparison-col">
            <span class="defn-comparison-label">{{ term.official_concept?.edition_label || 'VIM/VIML' }} (authoritative)</span>
            <p class="defn-comparison-text"><DefText :text="vimDefinition" /></p>
          </div>
        </div>
        <p class="defn-comparison-note">The wording differs. TC 1 should decide: update to match VIM/VIML, or document why divergence is intentional.</p>
      </div>

      <!-- Concept diff: what changed between cited and latest editions -->
      <ConceptDiffView v-if="term.official_concept?.concept_diff" :diff="term.official_concept.concept_diff" />

      <!-- EVIDENCE: concept version cards below the action -->
      <div class="concept-evidence">
        <div class="concept-evidence-head">
          <h3>Evidence — VIM / VIML concept</h3>
          <a v-if="term.official_concept?.url" class="external" :href="term.official_concept.url" style="font-size:0.85em">view on vocab site ↗</a>
        </div>

        <!-- Language toggle (shown when eng + fra both available) -->
        <div v-if="fullConceptLangs.length > 1" class="sort-toggle" style="margin:0.6em 0">
          <button v-for="lang in fullConceptLangs" :key="lang"
                  type="button"
                  :class="['sort-btn', { 'sort-btn-active': fullConceptLang === lang }]"
                  @click="fullConceptLang = lang">
            {{ lang === 'eng' ? 'English' : lang === 'fra' ? 'Français' : lang }}
          </button>
        </div>

        <!-- Concept version series -->
        <div class="concept-series">
          <template v-for="(v, i) in conceptVersions" :key="i">
            <!-- Connector between versions -->
            <div v-if="i > 0" :class="['concept-version-connector', { 'concept-version-connector-cross': v.crossVocab }]">
              <div class="concept-version-connector-line"></div>
              <span class="concept-version-connector-label">
                {{ conceptVersions[i - 1].vocab === v.vocab ? "superseded by" : "also defined in" }}
              </span>
            </div>

            <!-- Version card -->
            <div :class="['concept-version-card', `concept-version-card-${v.status}`, { 'concept-version-card-cross': v.crossVocab }]">
              <div class="concept-version-bar"></div>
              <div class="concept-version-body">
                <div class="concept-version-head">
                  <span v-if="v.crossVocab" class="concept-version-badge concept-version-badge-cross-vocab">Cross-vocab</span>
                  <span :class="['concept-version-badge', `concept-version-badge-${v.status}`]">
                    {{ v.status === "current" ? "Current" : v.status === "superseded" ? "Superseded" : "Removed" }}
                  </span>
                  <span class="concept-version-source">{{ v.label }}</span>
                  <span class="concept-version-id">#{{ v.conceptId }}</span>
                  <a v-if="v.url" class="concept-version-link" :href="v.url">view ↗</a>
                </div>

                <div v-if="v.status === 'current'" class="concept-version-use-this">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                  TC 1 should cite this version
                </div>

                <div class="concept-version-divider"></div>

                <ConceptBody v-if="v.data" :data="v.data" />
                <p v-else-if="v.fallbackDef" class="concept-defn-body"><DefText :text="v.fallbackDef" /></p>
              </div>
            </div>
          </template>
        </div>

        <!-- Removal warning (only when no cross-vocab current version exists) -->
        <div v-if="conceptState === 'removed' && !conceptVersions.some(v => v.status === 'current')" class="admonition warn" style="margin-top:0.6em">
          <strong>Removed from {{ term.latest_check?.latest_label }}.</strong>
          <template v-if="term.canonical_mismatch"> A similar term exists: <strong>{{ term.canonical_mismatch.designation }}</strong> (#{{ term.canonical_mismatch.concept_id }}).</template>
        </div>

        <!-- See also: same-vocabulary cross-references to other concepts -->
        <div v-if="seeAlso.length" class="concept-see-also">
          <span class="concept-see-also-label">Cross-referenced in {{ seeAlso[0].ref.edition_label || label(seeAlso[0].ref.source) }}</span>
          <div class="concept-see-also-items">
            <a v-for="(item, i) in seeAlso" :key="i" class="concept-see-also-link" :href="item.url || '#'">
              #{{ item.ref.id }} ↗
            </a>
          </div>
          <p class="concept-see-also-hint">These are different concepts that the source vocabulary points to as related.</p>
        </div>
      </div>
    </section>

    <section v-if="allAnnotations.length" class="card admonition warn">
      <h2 style="margin-top:0">Annotations</h2>
      <ul style="margin:0;padding-left:1.2em">
        <li v-for="(ann, i) in allAnnotations" :key="i" style="margin-bottom:0.4em">{{ ann.text }}</li>
      </ul>
    </section>

    <section v-if="hasMultiSourceParagraphs" class="card admonition warn">
      <h2 style="margin-top:0">Multi-source paragraphs detected</h2>
      <p style="margin:0">Some definition paragraphs cite <strong>multiple sources</strong> (e.g. adapted from VIM with additions from VIML). Review the Source column in Publication instances below for the full citation chain.</p>
    </section>

    <!-- Operative definition: shown when there's no authoritative VIM/VIML
         source (OIML-original term). Surfaces the most-cited wording so
         the page leads with the actual definition instead of forcing the
         user to dig into Publication instances. -->
    <section v-if="operativeDefinition" class="card">
      <h2>Definition</h2>
      <div class="authority-defn">
        <span class="badge">OIML-original</span>
        · <strong>{{ operativeDefinition.pubCount }}</strong> publication{{ operativeDefinition.pubCount === 1 ? '' : 's' }}
        <span v-if="operativeDefinition.distinctCount > 1"> · {{ operativeDefinition.distinctCount }} distinct wordings — see <a href="#pub-instances">Publication instances</a> for the variants</span>
        <p class="authority-defn-body"><DefText :text="operativeDefinition.text" /></p>
      </div>
    </section>

    <section class="card" v-if="designations.length && (admittedExpressions.length || symbolDesignations.length || abbreviations.length || (!showConceptCard && preferredExpression))">
      <h2>G 18 designations</h2>
      <dl class="designations">
        <div v-if="preferredExpression" class="designations-row">
          <dt>Term (preferred)</dt>
          <dd>
            <DefText :text="preferredExpression" />
            <span v-if="preferredUsage" class="usage-info">[{{ preferredUsage }}]</span>
          </dd>
        </div>
        <template v-for="(ad, i) in admittedExpressions" :key="'ad-'+i">
          <div class="designations-row">
            <dt>Term (admitted)</dt>
            <dd><DefText :text="ad.text" /><span v-if="ad.usage" class="usage-info">[{{ ad.usage }}]</span></dd>
          </div>
        </template>
        <template v-for="(sym, i) in symbolDesignations" :key="'sym-'+i">
          <div class="designations-row">
            <dt>Symbol<span v-if="sym.international" class="intl-pill" title="Internationally recognised">intl</span></dt>
            <dd><DefText :text="sym.text" /></dd>
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
      <div class="table-scroll">
      <table>
        <thead><tr><th>Source</th><th>Relationship</th><th>Publications</th><th>Where</th></tr></thead>
        <tbody>
          <tr v-for="(g, i) in provenanceGroups" :key="i">
            <td><strong>{{ g.label }}</strong><br /><span class="muted">{{ g.ref || '—' }}</span></td>
            <td><span :class="['rel-pill', `rel-${g.relationship}`]">{{ g.relationship }}</span></td>
            <td class="num">{{ g.pubs.length }}</td>
            <td>
              <span v-for="(p, pi) in g.pubs.slice(0, 5)" :key="pi" class="prov-pub">
                <SLink :to="`/publications/${slugify(p.publication_id)}/`">{{ p.publication }}</SLink>
                <span class="muted"> ({{ p.edition }})</span>
              </span>
              <span v-if="g.pubs.length > 5" class="muted"> +{{ g.pubs.length - 5 }} more</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
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

    <section class="card" id="pub-instances">
      <div class="card-head">
        <h2>Reference — definitions used across publications</h2>
        <div style="display:flex;gap:1em;align-items:center;flex-wrap:wrap">
          <label><input type="checkbox" v-model="groupMode" /> Group identical</label>
          <select v-model="onlyTC" v-if="allTCs.length > 1" aria-label="Filter by TC/SC">
            <option value="">All TC/SCs</option>
            <option v-for="tc in allTCs" :key="tc" :value="tc">{{ tc }}</option>
          </select>
        </div>
      </div>

      <!-- Consistency legend -->
      <div v-if="hasConsistencyData" class="consistency-legend">
        <span class="legend-item"><span class="badge badge-ok">ok</span> matches VIM/VIML</span>
        <span class="legend-item"><span class="badge badge-partial">partial</span> some divergence</span>
        <span class="legend-item"><span class="badge badge-ko">ko</span> significant divergence</span>
        <span class="legend-item"><span class="badge badge-pending">pending</span> not yet classified</span>
      </div>

      <!-- Grouped mode: show definition groups -->
      <template v-if="groupMode">
        <p class="lede" style="margin-bottom:0.5em">
          <span v-if="worstEditionDistinctCount <= 1 && Object.keys(distinctDefsByEdition).length > 1">
            <strong>Consistent within each edition</strong> — different wording across editions is intentional editorial evolution, not a conflict.
            <span v-for="(defs, ed) in distinctDefsByEdition" :key="ed">{{ ed }}: {{ defs.length }} definition{{ defs.length === 1 ? '' : 's' }}. </span>
          </span>
          <span v-else>
            <strong>{{ definitionGroups.length }}</strong> distinct definitions across
            <strong>{{ definitionGroups.reduce((s, g) => s + g.count, 0) }}</strong> publications.
            <span v-if="sharedGroups.length">{{ sharedGroups.length }} definitions are shared by multiple publications (merge candidates).</span>
          </span>
        </p>

        <!-- Shared definition groups (count > 1) -->
        <div v-for="(g, i) in sharedGroups" :key="i" class="def-group">
          <div class="def-group-head">
            <span class="def-group-badge">{{ g.count }} identical</span>
            <span v-for="ed in g.editions" :key="ed" :class="['edition-pill', `edition-${ed.toLowerCase()}`]">{{ ed }}</span>
          </div>
          <div class="def-group-text"><DefText :text="g.definition" /></div>
          <div class="table-scroll">
      <table class="def-group-pubs">
            <thead><tr><th>Ed.</th><th>Year</th><th>Publication</th><th>Clause</th><th>G 18 #</th><th v-if="hasConsistencyData">Consistency</th></tr></thead>
            <tbody>
              <tr v-for="p in g.publications" :key="p.g18_entry">
                <td><span :class="['edition-pill', `edition-${p.edition?.toLowerCase()}`]">{{ p.edition }}</span></td>
                <td class="num">{{ p.year }}</td>
                <td><SLink :to="`/publications/${slugify(p.publication_id)}/`">{{ p.publication }}</SLink></td>
                <td class="num">{{ p.clause }}</td>
                <td class="num">{{ p.g18_entry }}</td>
                <td v-if="hasConsistencyData"><span :class="['badge', `badge-${p.consistency || 'pending'}`]" :title="consistencyHint(p.consistency || 'pending')">{{ p.consistency || "pending" }}</span></td>
              </tr>
            </tbody>
          </table>
    </div>
        </div>

        <!-- Unique definitions (count === 1) -->
        <div v-if="uniqueGroups.length" class="def-group-unique-section">
          <h3>{{ uniqueGroups.length }} unique definition{{ uniqueGroups.length === 1 ? '' : 's' }} (each used by only one publication)</h3>
          <div class="table-scroll">
      <table>
            <thead><tr><th>Ed.</th><th>Year</th><th>Publication</th><th>Clause</th><th>G 18 #</th><th>Definition</th><th v-if="hasConsistencyData"></th></tr></thead>
            <tbody>
              <tr v-for="g in uniqueGroups" :key="g.publications[0].g18_entry" class="row-divergent">
                <td><span :class="['edition-pill', `edition-${g.publications[0].edition?.toLowerCase()}`]">{{ g.publications[0].edition }}</span></td>
                <td class="num">{{ g.publications[0].year }}</td>
                <td><SLink :to="`/publications/${slugify(g.publications[0].publication_id)}/`">{{ g.publications[0].publication }}</SLink></td>
                <td class="num">{{ g.publications[0].clause }}</td>
                <td class="num">{{ g.publications[0].g18_entry }}</td>
                <td style="max-width:400px"><div style="white-space:pre-wrap;font-size:0.9em"><DefText :text="g.definition" /></div></td>
                <td v-if="hasConsistencyData"><span :class="['badge', `badge-${g.publications[0].consistency || 'pending'}`]" :title="consistencyHint(g.publications[0].consistency || 'pending')">{{ g.publications[0].consistency || "pending" }}</span></td>
              </tr>
            </tbody>
          </table>
    </div>
        </div>
      </template>

      <!-- Flat mode: original table -->
      <template v-else>
        <div class="table-scroll">
      <table>
          <thead><tr><th>Ed.</th><th>Year</th><th>Publication</th><th>Clause</th><th>G 18 #</th><th>Definition</th><th>Match</th><th>Notes</th><th>Source</th><th v-if="hasConsistencyData">Consistency</th></tr></thead>
          <tbody>
            <tr v-for="p in filteredPublications" :key="p.g18_entry" v-show="rowVisible(p)" :class="{ 'row-divergent': distinctDefs.length > 1 && p.definition?.trim() !== distinctDefs[0], 'row-modified': p.source?.relationship === 'modified', 'row-differs': pubMatchStatus(p).key === 'differs' }">
              <td><span :class="['edition-pill', `edition-${p.edition?.toLowerCase()}`]">{{ p.edition }}</span></td>
              <td class="num">{{ p.year }}</td>
              <td><SLink :to="`/publications/${slugify(p.publication_id)}/`">{{ p.publication }}</SLink><br /><span class="muted" style="font-size:0.8em">{{ p.tc_sc || '—' }}</span></td>
              <td class="num">{{ p.clause }}</td>
              <td class="num"><code>{{ p.g18_entry }}</code></td>
              <td style="max-width:540px">
                <div v-for="(para, pi) in (p.definition_paragraphs && p.definition_paragraphs.length ? p.definition_paragraphs : [{text: p.definition, sources: []}])" :key="pi" class="def-para">
                  <div style="white-space:pre-wrap"><DefText :text="para.text" /></div>
                  <div v-if="para.sources && para.sources.length" class="para-sources">
                    <span v-for="(s, si) in para.sources" :key="si" :class="['rel-pill', `rel-${s.relationship}`]">
                      {{ s.ref_source }}{{ s.ref_id ? ' §' + s.ref_id : '' }} ({{ s.relationship }})
                    </span>
                  </div>
                  <div v-if="para.sources && para.sources.some(s => s.modification)" class="para-mod">
                    <strong>Modified:</strong> {{ para.sources.find(s => s.modification).modification }}
                  </div>
                </div>
              </td>
              <td><span :class="['match-pill', `match-${pubMatchStatus(p).key}`]">{{ pubMatchStatus(p).label }}</span></td>
              <td v-if="(p.notes || []).length" style="max-width:320px"><ul class="inline-notes"><li v-for="(n, ni) in p.notes" :key="ni">{{ n }}</li></ul></td>
              <td v-else class="muted">—</td>
              <td>
                <span v-if="p.source" :class="['rel-pill', `rel-${p.source.relationship}`]" :title="p.source.modification || ''">
                  {{ p.source.kind }}: {{ p.source.relationship }}
                </span>
                <span v-else class="muted">OIML</span>
              </td>
              <td v-if="hasConsistencyData"><span :class="['badge', `badge-${p.consistency || 'pending'}`]" :title="consistencyHint(p.consistency || 'pending')">{{ p.consistency || "pending" }}</span></td>
            </tr>
          </tbody>
        </table>
    </div>
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
  background: var(--color-accent-tint);
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
  background: var(--color-paper-tint);
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
  color: var(--status-warn-text);
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
  background: var(--status-warn-bg);
  color: var(--status-warn-text);
  border-radius: 3px;
  font-size: 0.78em;
  font-style: italic;
}
.intl-pill {
  display: inline-block;
  margin-left: 0.4em;
  padding: 0.05em 0.4em;
  background: var(--status-ok-bg);
  color: var(--status-ok-text);
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
.rel-identical { background: var(--status-ok-bg); color: var(--status-ok-text); }
.rel-modified  { background: var(--status-warn-bg); color: var(--status-warn-text); }
.rel-authoritative { background: var(--status-info-bg); color: var(--status-info-text); }
.rel-derived   { background: var(--status-warn-bg); color: var(--status-warn-text); }
.rel-similar   { background: var(--status-neutral-bg); color: var(--status-neutral-text); }
.prov-pub { display: inline-block; margin-right: 0.6em; }
.row-modified { background: var(--status-warn-bg) !important; }
.row-differs { background: var(--status-error-bg) !important; }

.def-para {
  padding: 0.3em 0;
  border-bottom: 1px dashed var(--rule-soft);
}
.def-para:last-child { border-bottom: 0; }
.para-sources {
  margin-top: 0.3em;
  display: flex;
  flex-wrap: wrap;
  gap: 0.3em;
}
.para-mod {
  margin-top: 0.3em;
  padding: 0.3em 0.5em;
  background: var(--status-warn-bg);
  border-left: 3px solid var(--oiml-amber-deep);
  font-size: 0.85em;
  line-height: 1.4;
}

.match-pill {
  display: inline-block;
  padding: 0.1em 0.5em;
  border-radius: 3px;
  font-size: 0.74em;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  white-space: nowrap;
}
.match-match { background: var(--status-ok-bg); color: var(--status-ok-text); }
.match-modified { background: var(--status-warn-bg); color: var(--status-warn-text); }
.match-differs { background: var(--status-error-bg); color: var(--status-error-text); }
.match-empty, .match-nobaseline { background: var(--status-neutral-bg); color: var(--status-neutral-text); }

/* G 18 ID chip */
.term-meta-row {
  display: flex;
  align-items: center;
  gap: 0.5em;
  flex-wrap: wrap;
  margin-top: 0.3em;
}
.g18-chip {
  display: inline-flex;
  align-items: center;
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 600;
  padding: 0.15em 0.5em;
  border-radius: 9999px;
  background: var(--color-rule-soft);
  color: var(--color-ink-soft);
  letter-spacing: 0.02em;
}

/* Sourcing documents in page header */
.sourcing-docs {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.3em 0.4em;
  margin-top: 0.4em;
}
.sourcing-label {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-ink-muted);
  margin-right: 0.2em;
}
.sourcing-doc {
  font-family: var(--font-mono);
  font-size: 0.76rem;
  padding: 0.1em 0.45em;
  border-radius: 3px;
  background: var(--color-rule-soft);
  text-decoration: none;
  color: var(--color-ink-soft);
}
.sourcing-doc:hover {
  background: var(--color-accent-tint);
  color: var(--color-accent);
}
.sourced-from {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 0.3em;
  margin-top: 0.4em;
}
.sourced-from-label {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-ink-muted);
}
.sourced-from-chip {
  font-family: var(--font-mono);
  font-size: 0.74rem;
  padding: 0.1em 0.45em;
  border-radius: 3px;
  border-left: 3px solid;
}
.sf-vocab { background: var(--status-ok-bg); color: var(--status-ok-text); border-left-color: var(--status-ok-border); }
.sf-oiml { background: var(--status-info-bg); color: var(--status-info-text); border-left-color: var(--status-info-border); }
.sf-external { background: var(--status-warn-bg); color: var(--status-warn-text); border-left-color: var(--status-warn-border); }
.sf-other { background: var(--color-rule-soft); color: var(--color-ink-soft); border-left-color: var(--color-rule); }
.sourcing-more {
  font-size: 0.76rem;
  color: var(--color-ink-muted);
  font-style: italic;
}

/* Near-miss candidates in decision flow */
.near-miss-list {
  display: flex;
  flex-direction: column;
  gap: 0.3em;
  margin: 0.4em 0;
}
.near-miss-item {
  display: inline-flex;
  align-items: center;
  gap: 0.4em;
  padding: 0.3em 0.6em;
  border-radius: 4px;
  background: var(--color-paper-soft);
  border: 1px solid var(--color-rule-soft);
  text-decoration: none;
  font-size: 0.84rem;
  color: var(--color-ink);
}
.near-miss-item:hover {
  background: var(--color-accent-tint);
  border-color: var(--color-accent-soft);
}
.near-miss-vocab {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  padding: 0.1em 0.35em;
  border-radius: 2px;
  background: var(--color-accent);
  color: #fff;
}
.near-miss-sim {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  color: var(--color-ink-muted);
  margin-left: auto;
}

/* Definition comparison */
.defn-comparison {
  margin: 0.6em 0;
  padding: 0.7em 0.9em;
  background: var(--color-paper-soft);
  border: 1px solid var(--color-rule-soft);
  border-radius: 4px;
}
.defn-comparison-head {
  font-size: 0.66rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-ink-muted);
  margin-bottom: 0.4em;
}
.defn-comparison-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.8em;
}
@media (max-width: 640px) {
  .defn-comparison-grid { grid-template-columns: 1fr; }
}
.defn-comparison-col {}
.defn-comparison-label {
  display: block;
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--color-ink-muted);
  margin-bottom: 0.2em;
}
.defn-comparison-text {
  font-size: 0.84rem;
  line-height: 1.5;
  color: var(--color-ink);
  margin: 0;
}
.defn-comparison-note {
  font-size: 0.78rem;
  color: var(--color-oiml-amber-deep);
  margin: 0.5em 0 0;
  font-style: italic;
}

/* Recommendations banner */
.recommendations-banner {
  display: flex;
  align-items: center;
  gap: 0.8em;
  padding: 0.7em 1em;
  margin-bottom: 1.2em;
  border-radius: 6px;
  border-left: 4px solid;
}
.rec-ok { background: var(--status-ok-bg); border-color: var(--status-ok-border); }
.rec-warn { background: var(--status-warn-bg); border-color: var(--status-warn-border); }
.rec-info { background: var(--status-info-bg); border-color: var(--status-info-border); }
.rec-none { display: none; }
.rec-icon { font-size: 1.3rem; flex-shrink: 0; }
.rec-body { flex: 1; }
.rec-label {
  font-size: 0.64rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  opacity: 0.7;
  margin-bottom: 0.1em;
}
.rec-text { font-size: 0.88rem; line-height: 1.4; }
.rec-action {
  flex-shrink: 0;
  padding: 0.35em 0.8em;
  border-radius: 4px;
  background: var(--color-accent);
  color: #fff !important;
  font-size: 0.82rem;
  font-weight: 600;
  text-decoration: none;
  white-space: nowrap;
}
.rec-action:hover { background: var(--color-accent-hover); text-decoration: none; }

/* Withdrawn publication warning */
.withdrawn-warning {
  display: flex;
  align-items: flex-start;
  gap: 0.7em;
  padding: 0.7em 1em;
  margin-bottom: 1.2em;
  border-radius: 6px;
  background: var(--status-error-bg);
  border-left: 4px solid var(--status-error-border);
}
.withdrawn-warning-icon {
  font-size: 1.2rem;
  flex-shrink: 0;
  color: var(--status-error-text);
}
.withdrawn-warning-body {
  flex: 1;
}
.withdrawn-warning-text {
  font-size: 0.88rem;
  color: var(--status-error-text);
  line-height: 1.4;
}
.withdrawn-warning-text strong {
  font-weight: 700;
}
.withdrawn-pub-id {
  font-family: var(--font-mono);
  font-size: 0.82rem;
  font-weight: 600;
}
.withdrawn-pub-id a {
  color: var(--status-error-text);
}
.withdrawn-warning-action {
  font-size: 0.82rem;
  font-weight: 600;
  margin-top: 0.3em;
  color: var(--status-error-text);
  opacity: 0.85;
}

/* Publication citation status */
.citation-status-card { margin-bottom: 1.2em; }
.citation-summary {
  display: flex;
  gap: 0.6em;
  font-size: 0.78rem;
  font-weight: 600;
}
.citation-count { padding: 0.1em 0.45em; border-radius: 3px; }
.citation-count-current { background: var(--status-ok-bg); color: var(--status-ok-text); }
.citation-count-outdated { background: var(--status-warn-bg); color: var(--status-warn-text); }
.citation-count-nocite { background: var(--color-rule-soft); color: var(--color-ink-muted); }

.citation-list {
  display: flex;
  flex-direction: column;
  gap: 0;
}
.citation-row {
  display: flex;
  align-items: center;
  gap: 0.5em;
  padding: 0.5em 0;
  border-bottom: 1px solid var(--color-rule-soft);
}
.citation-row:last-child { border-bottom: 0; }
.citation-pub {
  font-family: var(--font-mono);
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-ink);
  text-decoration: none;
  min-width: 12em;
}
.citation-pub:hover { color: var(--color-accent); }
.citation-pub-edition {
  font-size: 0.68rem;
  color: var(--color-ink-muted);
  padding: 0.05em 0.3em;
  border-radius: 2px;
  background: var(--color-rule-soft);
}
.citation-arrow {
  color: var(--color-ink-muted);
  font-size: 0.8rem;
}
.citation-ref {
  font-size: 0.82rem;
  font-weight: 500;
  flex: 1;
}
.citation-ref-current { color: var(--status-ok-text); }
.citation-ref-outdated { color: var(--status-warn-text); }
.citation-ref-no-citation { color: var(--color-ink-muted); }
.citation-action {
  font-size: 0.72rem;
  font-weight: 600;
  padding: 0.15em 0.5em;
  border-radius: 3px;
  white-space: nowrap;
}
.citation-action-ok { background: var(--status-ok-bg); color: var(--status-ok-text); }
.citation-action-warn { background: var(--status-warn-bg); color: var(--status-warn-text); }
.citation-action-info { background: var(--color-rule-soft); color: var(--color-ink-muted); }

/* Decision flow box */
.decision-box {
  background: var(--color-accent-tint);
  border: 1px solid var(--color-accent-soft);
  border-radius: 6px;
  padding: 1em 1.2em;
  margin-bottom: 1.2em;
}
.decision-box {
  order: 99;
}
section.card:has(> .decision-box) {
  display: flex;
  flex-direction: column;
}
.decision-box h2 {
  font-size: 1rem;
  font-weight: 600;
  margin: 0 0 0.5em;
  color: var(--color-accent);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.decision-recommendation {
  margin-top: 0.5em;
}
.decision-path {
  font-size: 0.88rem;
  color: var(--color-ink);
  line-height: 1.5;
}
.decision-path-ok {
  color: var(--color-green);
}
.decision-options {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5em;
  margin-top: 0.5em;
}
.decision-option {
  display: inline-block;
  padding: 0.3em 0.8em;
  border-radius: 4px;
  background: var(--color-accent);
  color: #fff !important;
  font-size: 0.82rem;
  font-weight: 600;
  text-decoration: none;
  white-space: nowrap;
}
.decision-option:hover {
  background: var(--color-accent-hover);
  text-decoration: none;
}

/* Proposal CTA for OIML-original terms */
.proposal-cta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1em;
  flex-wrap: wrap;
  padding: 0.8em 1.1em;
  margin-bottom: 1.2em;
  border-radius: 6px;
  background: var(--color-accent-tint);
  border: 1px solid var(--color-accent-soft);
}
.proposal-cta-label {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-accent);
  margin-bottom: 0.2em;
}
.proposal-cta-body p {
  margin: 0;
  font-size: 0.88rem;
  line-height: 1.45;
  color: var(--color-ink-soft);
}
.proposal-cta-btn {
  flex-shrink: 0;
  padding: 0.5em 1.1em;
  border-radius: 4px;
  background: var(--color-accent);
  color: #fff !important;
  font-weight: 600;
  font-size: 0.9rem;
  text-decoration: none;
  white-space: nowrap;
}
.proposal-cta-btn:hover {
  background: var(--color-accent-hover);
  text-decoration: none;
}

/* ── Action-first box: what TC 1 should do ─────────────────────── */
.concept-action-box {
  background: var(--color-accent-tint);
  border: 1px solid var(--color-accent);
  border-radius: 6px;
  padding: 1em 1.2em;
  margin-bottom: 1.2em;
}
.concept-action-box h2 {
  font-size: 1rem;
  font-weight: 600;
  margin: 0 0 0.6em;
  color: var(--color-accent);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.concept-action-items {
  display: flex;
  flex-direction: column;
  gap: 0.7em;
}
.concept-action-item {
  display: flex;
  gap: 0.7em;
  align-items: flex-start;
}
.concept-action-number {
  flex-shrink: 0;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--color-accent);
  color: #fff;
  font-size: 0.75rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 0.1em;
}
.concept-action-priority-high .concept-action-number { background: var(--color-red); }
.concept-action-priority-medium .concept-action-number { background: var(--color-oiml-amber); }
.concept-action-priority-low .concept-action-number { background: var(--color-accent); }
.concept-action-priority-info .concept-action-number { background: var(--color-ink-muted); }
.concept-action-content {
  flex: 1;
  min-width: 0;
}
.concept-action-title {
  font-weight: 600;
  font-size: 0.95rem;
  color: var(--color-ink);
  line-height: 1.3;
}
.concept-action-detail {
  font-size: 0.85rem;
  color: var(--color-ink-soft);
  line-height: 1.45;
  margin-top: 0.15em;
}
.concept-action-link {
  display: inline-block;
  margin-top: 0.3em;
  font-size: 0.82rem;
  font-weight: 600;
}

/* ── Evidence section ──────────────────────────────────────────── */
.concept-evidence-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.4em;
}
.concept-evidence-head h3 {
  font-size: 0.82rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-ink-muted);
  margin: 0;
}

/* Concept version series — vertical timeline of superseding cards */
.concept-series {
  display: flex;
  flex-direction: column;
  margin: 0.6em 0;
}

/* Connector between version cards — left-aligned rail bridging cards */
.concept-version-connector {
  display: flex;
  align-items: center;
  gap: 0.5em;
  margin-left: 0;
}
.concept-version-connector-line {
  width: 4px;
  height: 36px;
  background: var(--color-accent);
  opacity: 0.35;
  border-radius: 2px;
  flex-shrink: 0;
}
.concept-version-connector-label {
  font-size: 0.68rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 600;
  color: var(--color-ink-muted);
  white-space: nowrap;
}

/* Individual version card */
.concept-version-card {
  display: flex;
  border: 1px solid var(--color-rule);
  border-radius: 6px;
  overflow: hidden;
  background: var(--color-paper-soft);
  transition: border-color 0.15s, box-shadow 0.15s;
}

/* Left visual bar — color varies by status */
.concept-version-bar {
  width: 4px;
  flex-shrink: 0;
}
.concept-version-card-current .concept-version-bar { background: var(--color-accent); }
.concept-version-card-superseded .concept-version-bar { background: var(--status-warn-border); }
.concept-version-card-removed .concept-version-bar { background: var(--status-error-border); }

/* Current card: elevated, accent border */
.concept-version-card-current {
  border-color: var(--color-accent);
  box-shadow: 0 2px 8px -4px rgba(0, 73, 150, 0.2);
}

/* Cross-vocabulary cards: dashed teal border + bar to clearly differentiate
   from same-vocabulary version progression. */
.concept-version-card-cross {
  border-style: dashed;
  border-color: var(--oiml-teal, #024873);
}
.concept-version-card-cross .concept-version-bar {
  background: var(--oiml-teal, #024873);
}
.concept-version-card-cross.concept-version-card-current {
  border-style: dashed;
  border-color: var(--oiml-teal, #024873);
  box-shadow: 0 2px 8px -4px rgba(2, 72, 115, 0.25);
}

/* Cross-vocab badge */
.concept-version-badge-cross-vocab {
  background: var(--oiml-teal, #024873);
  color: #fff;
}

/* Cross-vocab connector: dashed teal line */
.concept-version-connector-cross .concept-version-connector-line {
  background: var(--oiml-teal, #024873);
  opacity: 0.5;
  border-left: 2px dashed var(--oiml-teal, #024873);
  background: transparent;
  width: 0;
}

/* Card body */
.concept-version-body {
  flex: 1;
  padding: 0.9em 1.1em;
  min-width: 0;
}

/* Header: badge + source + concept ID + link */
.concept-version-head {
  display: flex;
  align-items: center;
  gap: 0.5em;
  flex-wrap: wrap;
}
.concept-version-source {
  font-size: 0.88rem;
  font-weight: 600;
  color: var(--color-ink);
}
.concept-version-id {
  font-size: 0.78rem;
  color: var(--color-ink-muted);
  font-family: var(--font-mono);
}
.concept-version-link {
  margin-left: auto;
  font-size: 0.78rem;
  font-weight: 500;
}

/* Status badge */
.concept-version-badge {
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  padding: 0.15em 0.55em;
  border-radius: 3px;
  white-space: nowrap;
}
.concept-version-badge-current {
  background: var(--color-accent);
  color: #fff;
}
.concept-version-badge-superseded {
  background: var(--status-warn-bg);
  color: var(--status-warn-text);
}
.concept-version-badge-removed {
  background: var(--status-error-bg);
  color: var(--status-error-text);
}

/* "USE THIS VERSION" callout */
.concept-version-use-this {
  display: inline-flex;
  align-items: center;
  gap: 0.35em;
  margin: 0.5em 0 0.1em;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-accent);
}

/* Divider between header and concept body */
.concept-version-divider {
  height: 1px;
  background: var(--color-rule-soft);
  margin: 0.6em 0 0.4em;
}

/* Series intro text */
.concept-series-intro {
  font-size: 0.85rem;
  color: var(--color-ink-soft);
  margin: 0.5em 0 0.8em;
  line-height: 1.5;
}

/* See Also: cross-references within the same vocabulary */
.concept-see-also {
  margin-top: 0.8em;
  padding: 0.6em 0.8em;
  border-radius: 4px;
  background: var(--color-paper-tint);
  border: 1px solid var(--color-rule-soft);
}
.concept-see-also-label {
  display: block;
  font-size: 0.66rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--color-ink-muted);
  margin-bottom: 0.3em;
}
.concept-see-also-items {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4em;
}
.concept-see-also-link {
  font-family: var(--font-mono);
  font-size: 0.8rem;
  padding: 0.1em 0.5em;
  border-radius: 3px;
  background: var(--color-paper-soft);
  border: 1px solid var(--color-rule-soft);
  text-decoration: none;
}
.concept-see-also-link:hover {
  background: var(--color-accent-tint);
  border-color: var(--color-accent);
}
.concept-see-also-hint {
  font-size: 0.78rem;
  color: var(--color-ink-muted);
  margin: 0.4em 0 0;
  font-style: italic;
}

/* Consistency legend */
.consistency-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.8em 1.5em;
  padding: 0.5em 0 0.7em;
  margin-bottom: 0.3em;
  border-bottom: 1px solid var(--color-rule-soft);
  font-size: 0.8rem;
  color: var(--color-ink-soft);
}
.legend-item {
  display: inline-flex;
  align-items: center;
  gap: 0.35em;
}
.legend-item .badge {
  font-size: 0.72rem;
}

.vocab-concept-comparison {
  margin: 1em 0;
  padding: 0;
}
.vocab-concept-comparison-head {
  font-size: 0.82rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--color-ink-muted);
  margin-bottom: 0.6em;
}
.vocab-concept-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 0.8em;
}
.vocab-concept-card {
  padding: 1em 1.2em;
  border-radius: var(--radius-card);
  border: 1px solid var(--color-rule);
  border-left: 4px solid;
  background: var(--color-paper);
}
.vocab-concept-viml { border-left-color: var(--status-ok-border); }
.vocab-concept-vim { border-left-color: var(--status-info-border); }
.vocab-concept-badge {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  opacity: 0.7;
  margin-bottom: 0.3em;
}
.vocab-concept-viml .vocab-concept-badge { color: var(--status-ok-text); }
.vocab-concept-vim .vocab-concept-badge { color: var(--status-info-text); }
.vocab-concept-designation {
  font-family: var(--font-display);
  font-size: 1.15rem;
  font-weight: 500;
  color: var(--color-ink);
  margin-bottom: 0.5em;
  font-style: italic;
  letter-spacing: -0.01em;
}
.vocab-concept-admitted {
  font-size: 0.82rem;
  color: var(--color-ink-soft);
  font-style: italic;
  margin-bottom: 0.5em;
}
.vocab-usage {
  font-weight: 600;
  font-style: normal;
  color: var(--color-ink-muted);
  font-size: 0.85em;
}
.vocab-concept-def {
  font-size: 0.9rem;
  line-height: 1.55;
  color: var(--color-ink-soft);
  margin: 0 0 0.5em;
}
.vocab-concept-notes {
  margin: 0.3em 0 0.5em;
  padding: 0;
}
.vocab-note {
  font-size: 0.82rem;
  line-height: 1.5;
  color: var(--color-ink-soft);
  padding: 0.3em 0 0.3em 1em;
  border-left: 2px solid var(--color-rule-soft);
  margin-bottom: 0.3em;
}
.vocab-concept-examples {
  margin: 0.3em 0 0.5em;
  padding: 0;
}
.vocab-example {
  font-size: 0.82rem;
  line-height: 1.45;
  color: var(--color-ink-soft);
  padding: 0.3em 0 0.3em 1em;
  border-left: 2px solid var(--color-rule-soft);
  margin-bottom: 0.3em;
}
.vocab-example em {
  font-style: normal;
  font-weight: 600;
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-ink-muted);
  margin-right: 0.3em;
}
.vocab-concept-link {
  display: inline-block;
  margin-top: 0.4em;
  font-size: 0.82rem;
  font-weight: 600;
}
</style>
