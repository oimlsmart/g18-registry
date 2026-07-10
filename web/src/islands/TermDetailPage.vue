<script setup lang="ts">
import { computed, ref, watchEffect } from "vue";
import termBySlug from "@/data/term-by-slug.json";
import { useVocabularyEdition } from "@/composables/useVocabularyEdition";
import { isOimlOriginal } from "@/composables/useSuggestedActions";
import { slugifyPubId } from "@/composables/useSuggestedActions";
import SLink from "@/components/SLink.vue";
import DefText from "@/components/DefText.vue";
import ConceptBody from "@/components/ConceptBody.vue";

const props = defineProps<{ slug: string }>();
const { label, confidenceClass, isCurrent, isSuperseded, latestLabel, role, vocabUrl } = useVocabularyEdition();

const term = computed(() => (termBySlug as any)[props.slug]);

// Edition filter (single-select, mirrors the publication/TC pages).
// Drives the `enabledEditions` Set used downstream by the definition-group
// and Publication instances tables.
type EditionFilter = "202X" | "2010" | "all";
const editionFilter = ref<EditionFilter>("all");

// Default to 202X when the term is in the draft edition — TC 1 acts there.
// 2010-only terms default to "all" (the historic callout above handles them).
watchEffect(() => {
  if (!term.value) return;
  const eds = term.value.editions_present || [];
  if (eds.includes("202X")) editionFilter.value = "202X";
  else editionFilter.value = "all";
});

const enabledEditions = computed(() => {
  const eds = term.value?.editions_present || [];
  if (editionFilter.value === "all") return new Set(eds);
  return new Set(eds.filter(e => e === editionFilter.value));
});
const groupMode = ref(true);

function editionCount(ed: string): number {
  return (term.value?.publications || []).filter(p => p.edition === ed).length;
}

function setEditionFilter(f: EditionFilter) {
  editionFilter.value = f;
}

function kindLabel(k: string) { return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—"; }

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

const consistencyCounts = computed(() => {
  if (!term.value) return { ok: 0, partial: 0, ko: 0, pending: 0 } as Record<string, number>;
  const c: Record<string, number> = { ok: 0, partial: 0, ko: 0, pending: 0 };
  for (const p of term.value.publications) c[p.consistency || "pending"] = (c[p.consistency || "pending"] || 0) + 1;
  return c;
});

const matchStatus = computed(() => {
  if (!term.value) return null;
  if (isOimlOriginal(term.value)) return { key: "notinviml", label: "Not in VIM/VIML" };
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
  if (isOimlOriginal(term.value)) {
    a.push({ priority: "high", text: "No authoritative definition in VIM or VIML." });
  }
  if (worstEditionDistinctCount.value > 1) {
    a.push({
      priority: "medium",
      text: `${worstEditionDistinctCount.value} distinct definitions WITHIN ${worstEdition.value} — harmonise within that edition.`,
    });
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
const isHistoricTerm = computed(() => {
  const eds = term.value?.editions_present || [];
  return eds.length > 0 && eds.every(e => e === "2010");
});

// Full VIM/VIML concept content (designations, definitions, notes,
// examples) loaded from the vocab repo at export time. Shows TC 1
// the complete authoritative target on the term detail page.
const citedConcept = computed(() => term.value?.official_concept?.cited_concept || null);
const latestConcept = computed(() => term.value?.official_concept?.latest_concept || null);
const fullConceptLangs = computed(() => {
  const fc = latestConcept.value || citedConcept.value;
  return fc ? Object.keys(fc) : [];
});
const fullConceptLang = ref("eng");
function conceptData(source: any) {
  if (!source) return null;
  return source[fullConceptLang.value] || source["eng"] || Object.values(source)[0] || null;
}
// Determine the VIM/VIML relationship state for UI rendering:
// - 'none': OIML-original, no concept card
// - 'current': term cites the latest edition, content matches
// - 'upgrade': term cites old edition, available in latest (may have different content/id)
// - 'removed': term not found in latest edition
const conceptState = computed(() => {
  const oc = term.value?.official_concept;
  if (!oc || isOimlOriginal(term.value)) return "none";
  const lc = term.value?.latest_check;
  if (lc && !lc.found) return "removed";
  if (citedConcept.value && latestConcept.value && lc && lc.found &&
      oc.id !== lc.concept_id) return "upgrade";
  return "current";
});
const showConceptCard = computed(() => conceptState.value !== "none");

interface ConceptVersion {
  label: string;
  conceptId: string;
  data: any;
  status: "current" | "superseded" | "removed";
  url?: string;
  fallbackDef?: string;
  vocab: string;
}
function refVocabOf(ref: any): string {
  return ref.vocab || (ref.source?.includes("v:1:") ? "viml" : "vim");
}
const conceptVersions = computed<ConceptVersion[]>(() => {
  if (!showConceptCard.value || !term.value?.official_concept) return [];
  const oc = term.value.official_concept;
  const versions: ConceptVersion[] = [];
  const seen = new Set<string>();
  function addVersion(v: ConceptVersion) {
    const key = `${v.label}#${v.conceptId}`;
    if (seen.has(key)) return;
    seen.add(key);
    versions.push(v);
  }

  if (conceptState.value === "upgrade") {
    addVersion({
      label: oc.edition_label || label(oc.source),
      conceptId: oc.id,
      data: conceptData(citedConcept.value),
      status: "superseded",
      fallbackDef: !conceptData(citedConcept.value) ? oc.definition_text : undefined,
      vocab: refVocabOf(oc),
    });
    addVersion({
      label: term.value.latest_check?.latest_label || latestLabel(oc.source),
      conceptId: term.value.latest_check?.concept_id || "?",
      data: conceptData(latestConcept.value),
      status: "current",
      url: term.value.latest_check?.url,
      vocab: refVocabOf(oc),
    });
  } else if (conceptState.value === "removed") {
    addVersion({
      label: oc.edition_label || label(oc.source),
      conceptId: oc.id,
      data: conceptData(citedConcept.value),
      status: "removed",
      fallbackDef: !conceptData(citedConcept.value) ? oc.definition_text : undefined,
      vocab: refVocabOf(oc),
    });
  } else {
    const data = conceptData(latestConcept.value) || conceptData(citedConcept.value);
    addVersion({
      label: oc.edition_label || label(oc.source),
      conceptId: oc.id,
      data,
      status: "current",
      url: oc.url,
      fallbackDef: !data ? oc.definition_text : undefined,
      vocab: refVocabOf(oc),
    });
  }

  // Cross-vocabulary related concepts become version cards.
  const ocVocab = refVocabOf(oc);
  for (const edge of term.value.related || []) {
    const ref = edge.ref;
    if (!ref) continue;
    if (ref.source === oc.source && ref.id === oc.id) continue;
    if (refVocabOf(ref) === ocVocab) continue;
    const refData = ref.definition_text
      ? { designations: [], definitions: [ref.definition_text], notes: [], examples: [] }
      : null;
    addVersion({
      label: ref.edition_label || label(ref.source),
      conceptId: ref.id,
      data: refData,
      status: ref.role === "current" ? "current" : "superseded",
      url: vocabUrl(ref.source, ref.id) || undefined,
      fallbackDef: !refData ? ref.definition_text : undefined,
      vocab: refVocabOf(ref),
    });
  }
  return versions;
});

const seeAlso = computed(() => {
  if (!term.value?.related || !term.value?.official_concept) return [];
  const oc = term.value.official_concept;
  const ocVocab = refVocabOf(oc);
  return (term.value.related as any[])
    .filter(e => {
      const ref = e.ref;
      if (!ref) return false;
      if (ref.source === oc.source && ref.id === oc.id) return false;
      return refVocabOf(ref) === ocVocab;
    })
    .map(e => ({ ref: e.ref, url: vocabUrl(e.ref.source, e.ref.id) }));
});

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
  if (term.value.official_concept && !isOimlOriginal(term.value)) return null;
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

// Cross-edition drift: detect when 2010 and 202X have different
// authoritative sources or different definition text. The most important
// signal for TC1 reviewing 202X — did 202X intentionally diverge from
// 2010, or just refresh the source citation?
const crossEditionDrift = computed(() => {
  const pubs = term.value?.publications || [];
  const editions = new Set(pubs.map(p => p.edition));
  if (!(editions.has("2010") && editions.has("202X"))) return null;
  const e2010 = pubs.filter(p => p.edition === "2010");
  const e202X = pubs.filter(p => p.edition === "202X");
  const d2010 = new Set(e2010.map(p => normalizeDef(p.definition || "")).filter(Boolean));
  const d202X = new Set(e202X.map(p => normalizeDef(p.definition || "")).filter(Boolean));
  // Identical if every 2010 def appears in 202X and vice versa.
  const same = d2010.size === d202X.size && [...d2010].every(d => d202X.has(d));
  if (same) return null;
  const src2010 = e2010.map(p => p.source?.ref_source).filter(Boolean);
  const src202X = e202X.map(p => p.source?.ref_source).filter(Boolean);
  const srcChanged = JSON.stringify(src2010.sort()) !== JSON.stringify(src202X.sort());
  return {
    sameText: false,
    srcChanged,
    src2010: src2010[0] || null,
    src202X: src202X[0] || null,
    rel2010: e2010[0]?.source?.relationship || null,
    rel202X: e202X[0]?.source?.relationship || null,
  };
});

// Authoritative baseline text for match comparison. From the official
// concept (VIM/VIML citation).
const authoritativeText = computed(() => {
  const oc = term.value?.official_concept;
  return oc?.definition_text ? (oc.definition_text as string).trim() : "";
});

// Normalize VIM cross-reference markup ({{id,text}} → text) so VIM 2007
// (plain) and VIM 2012 (with refs) definitions compare as identical.
function normalizeDef(s: string): string {
  return (s || "").replace(/\{\{[^,}]+,([^}]+)\}\}/g, "$1").trim();
}

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
  <div v-if="!term" class="card"><p>Term not found.</p></div>
  <template v-else>
    <div class="page-head">
      <div class="breadcrumb"><SLink to="/">Registry</SLink> / <SLink to="/terms/">Terms</SLink> / <span>{{ term.name }}</span></div>
      <h1><DefText :text="term.name" /></h1>
      <p class="lede">
        <span :class="['kind', `kind-${term.kind}`]">{{ kindLabel(term.kind) }}</span>
        <span v-if="matchStatus" :class="['match-status', `match-status-${matchStatus.key}`]">{{ matchStatus.label }}</span>
        G 18 #{{ term.identifier }} · {{ term.publications.length }} instances
      </p>
    </div>

    <!-- Historic-only callout: term exists only in 2010. TC 1 cannot act. -->
    <section v-if="isHistoricTerm" class="card admonition" style="background: var(--color-paper-tint); border-color: var(--color-rule);">
      <strong>Historic (2010 only).</strong>
      This term appears only in the published G 18:2010 edition. TC 1 cannot
      take action on it — 2010 is frozen. Shown in worklists for completeness,
      visually deprioritized.
    </section>

    <!-- Sticky page-level edition filter (same pattern as publication/TC pages) -->
    <div v-if="!isHistoricTerm && (term.editions_present || []).length > 1" class="page-filter" role="region" aria-label="Edition filter">
      <span class="page-filter-label">Edition scope</span>
      <div class="page-filter-controls">
        <button v-if="(term.editions_present || []).includes('202X')" type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '202X' }]"
                @click="setEditionFilter('202X')">
          <span class="page-filter-btn-title">202X</span>
          <span class="page-filter-btn-meta">{{ editionCount('202X') }} instances · draft, TC 1 acts here</span>
        </button>
        <button v-if="(term.editions_present || []).includes('2010')" type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === '2010' }]"
                @click="setEditionFilter('2010')">
          <span class="page-filter-btn-title">2010</span>
          <span class="page-filter-btn-meta">{{ editionCount('2010') }} instances · historic, read-only</span>
        </button>
        <button type="button"
                :class="['page-filter-btn', { 'page-filter-btn-active': editionFilter === 'all' }]"
                @click="setEditionFilter('all')">
          <span class="page-filter-btn-title">All</span>
          <span class="page-filter-btn-meta">{{ term.publications.length }} instances · both editions</span>
        </button>
      </div>
    </div>

    <section class="card" v-if="showConceptCard">
      <div class="card-head">
        <h2>VIM / VIML concept</h2>
        <a v-if="term.official_concept.url" class="external" :href="term.official_concept.url" style="font-size:0.85em">view on vocab site ↗</a>
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

      <p class="concept-series-intro">
        Authoritative definitions from VIM (International Vocabulary of Metrology)
        and VIML (International Vocabulary of Legal Metrology). Each card shows
        one edition's full concept. <strong>Cite the current version.</strong>
      </p>

      <!-- Concept version series: superseded → current (or removed → cross-vocab) -->
      <div class="concept-series">
        <template v-for="(v, i) in conceptVersions" :key="i">
          <!-- Connector between versions -->
          <div v-if="i > 0" class="concept-version-connector">
            <div class="concept-version-connector-line"></div>
            <span class="concept-version-connector-label">
              {{ conceptVersions[i - 1].vocab === v.vocab ? "superseded by" : "also defined in" }}
            </span>
          </div>

          <!-- Version card -->
          <div :class="['concept-version-card', `concept-version-card-${v.status}`]">
            <div class="concept-version-bar"></div>
            <div class="concept-version-body">
              <div class="concept-version-head">
                <span :class="['concept-version-badge', `concept-version-badge-${v.status}`]">
                  {{ v.status === "current" ? "Current" : v.status === "superseded" ? "Superseded" : "Removed" }}
                </span>
                <span class="concept-version-source">{{ v.label }}</span>
                <span class="concept-version-id">#{{ v.conceptId }}</span>
                <a v-if="v.url" class="concept-version-link" :href="v.url">view on vocab site ↗</a>
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

    <section v-if="crossEditionDrift" class="card admonition warn">
      <h2 style="margin-top:0">Cross-edition drift</h2>
      <p style="margin:0.3em 0">
        The 2010 and 202X editions use <strong>different definition text</strong>
        <span v-if="crossEditionDrift.srcChanged"> and cite <strong>different sources</strong></span>.
        TC 1 must decide: is this an intentional update, or should 202X be re-aligned with 2010?
      </p>
      <div class="table-scroll">
      <table style="margin-top:0.5em;font-size:0.9em">
        <thead><tr><th>Edition</th><th>Source</th><th>Relationship</th></tr></thead>
        <tbody>
          <tr><td>2010</td><td>{{ crossEditionDrift.src2010 || '—' }}</td><td>{{ crossEditionDrift.rel2010 || '—' }}</td></tr>
          <tr><td>202X</td><td>{{ crossEditionDrift.src202X || '—' }}</td><td>{{ crossEditionDrift.rel202X || '—' }}</td></tr>
        </tbody>
      </table>
    </div>
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
                <SLink :to="`/publications/${slugifyPubId(p.publication_id)}/`">{{ p.publication }}</SLink>
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

    <section class="card" id="pub-instances">
      <div class="card-head">
        <h2>Publication instances</h2>
        <div style="display:flex;gap:1em;align-items:center;flex-wrap:wrap">
          <label><input type="checkbox" v-model="groupMode" /> Group identical</label>
          <select v-model="onlyTC" v-if="allTCs.length > 1" aria-label="Filter by TC/SC">
            <option value="">All TC/SCs</option>
            <option v-for="tc in allTCs" :key="tc" :value="tc">{{ tc }}</option>
          </select>
        </div>
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
                <td><SLink :to="`/publications/${slugifyPubId(p.publication_id)}/`">{{ p.publication }}</SLink></td>
                <td class="num">{{ p.clause }}</td>
                <td class="num">{{ p.g18_entry }}</td>
                <td v-if="hasConsistencyData"><span :class="['badge', `badge-${p.consistency || 'pending'}`]">{{ p.consistency || "pending" }}</span></td>
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
                <td><SLink :to="`/publications/${slugifyPubId(g.publications[0].publication_id)}/`">{{ g.publications[0].publication }}</SLink></td>
                <td class="num">{{ g.publications[0].clause }}</td>
                <td class="num">{{ g.publications[0].g18_entry }}</td>
                <td style="max-width:400px"><div style="white-space:pre-wrap;font-size:0.9em"><DefText :text="g.definition" /></div></td>
                <td v-if="hasConsistencyData"><span :class="['badge', `badge-${g.publications[0].consistency || 'pending'}`]">{{ g.publications[0].consistency || "pending" }}</span></td>
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
              <td><SLink :to="`/publications/${slugifyPubId(p.publication_id)}/`">{{ p.publication }}</SLink><br /><span class="muted" style="font-size:0.8em">{{ p.tc_sc || '—' }}</span></td>
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
              <td v-if="hasConsistencyData"><span :class="['badge', `badge-${p.consistency || 'pending'}`]">{{ p.consistency || "pending" }}</span></td>
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
</style>
