import { computed, ref, type ComputedRef, type Ref } from "vue";
import { useVocabularyEdition } from "@/composables/useVocabularyEdition";
import { isOimlSpecific } from "@/utils/edition-utils";

export interface ConceptVersion {
  label: string;
  conceptId: string;
  data: any;
  status: "current" | "superseded" | "removed";
  url?: string;
  fallbackDef?: string;
  vocab: string;
  crossVocab: boolean;
}

export interface ConceptAction {
  priority: string;
  title: string;
  detail: string;
  link?: string;
  label?: string;
}

export interface SeeAlsoItem {
  ref: any;
  url: string | null;
}

export type ConceptState = "none" | "current" | "upgrade" | "removed";

function refVocabOf(ref: any): string {
  return ref.vocab || (ref.source?.includes("v:1:") ? "viml" : "vim");
}

export function useConceptVersions(
  term: ComputedRef<any> | Ref<any>,
  worstEditionDistinctCount: ComputedRef<number> | Ref<number>,
) {
  const { label, isCurrent, isSuperseded, latestLabel, vocabUrl } = useVocabularyEdition();
  const fullConceptLang = ref("eng");

  const termVal = computed(() =>
    typeof term === "function" ? (term as ComputedRef<any>).value : (term as Ref<any>).value
  );

  const citedConcept = computed(() => termVal.value?.official_concept?.cited_concept || null);
  const latestConcept = computed(() => termVal.value?.official_concept?.latest_concept || null);

  const fullConceptLangs = computed(() => {
    const fc = latestConcept.value || citedConcept.value;
    return fc ? Object.keys(fc) : [];
  });

  function conceptData(source: any) {
    if (!source) return null;
    return source[fullConceptLang.value] || source["eng"] || Object.values(source)[0] || null;
  }

  const conceptState = computed<ConceptState>(() => {
    const t = termVal.value;
    const oc = t?.official_concept;
    if (!oc || isOimlSpecific(t.kind)) return "none";
    const lc = t?.latest_check;
    if (lc && !lc.found) return "removed";
    if (citedConcept.value && latestConcept.value && lc && lc.found &&
        oc.id !== lc.concept_id) return "upgrade";
    return "current";
  });

  const showConceptCard = computed(() => conceptState.value !== "none");

  const canPropose = computed(() =>
    termVal.value && (termVal.value.kind === "oiml_original" || !termVal.value.official_concept)
  );

  const conceptVersions = computed<ConceptVersion[]>(() => {
    const t = termVal.value;
    if (!showConceptCard.value || !t?.official_concept) return [];
    const oc = t.official_concept;
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
        crossVocab: false,
      });
      addVersion({
        label: t.latest_check?.latest_label || latestLabel(oc.source),
        conceptId: t.latest_check?.concept_id || "?",
        data: conceptData(latestConcept.value),
        status: "current",
        url: t.latest_check?.url,
        vocab: refVocabOf(oc),
        crossVocab: false,
      });
    } else if (conceptState.value === "removed") {
      addVersion({
        label: oc.edition_label || label(oc.source),
        conceptId: oc.id,
        data: conceptData(citedConcept.value),
        status: "removed",
        fallbackDef: !conceptData(citedConcept.value) ? oc.definition_text : undefined,
        vocab: refVocabOf(oc),
        crossVocab: false,
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
        crossVocab: false,
      });
    }

    const ocVocab = refVocabOf(oc);
    for (const edge of t.related || []) {
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
        crossVocab: true,
      });
    }
    return versions;
  });

  const worstCount = computed(() =>
    typeof worstEditionDistinctCount === "function"
      ? (worstEditionDistinctCount as ComputedRef<number>).value
      : (worstEditionDistinctCount as Ref<number>).value
  );

  const conceptActions = computed<ConceptAction[]>(() => {
    const t = termVal.value;
    if (!t?.suggested_actions) return [];
    const items: ConceptAction[] = [];
    for (const a of t.suggested_actions) {
      if (a.type === "removed" || a.type === "upgrade_vim" || a.type === "upgrade_viml") {
        const cv = conceptVersions.value.find(v => v.status === "current");
        if (cv) {
          items.push({
            priority: a.priority,
            title: `Cite ${cv.label} #${cv.conceptId} instead`,
            detail: a.description,
            link: cv.url,
            label: `View ${cv.label} concept ↗`,
          });
        } else {
          items.push({ priority: a.priority, title: "Update the G 18 citation", detail: a.description });
        }
      } else if (a.type === "harmonize") {
        const n = worstCount.value;
        items.push({
          priority: a.priority,
          title: `Harmonise ${n} distinct definition${n === 1 ? "" : "s"}`,
          detail: a.description,
        });
      } else if (a.type === "unique") {
        items.push({
          priority: a.priority,
          title: "Determine if this is a V 1/V 2/V 3 candidate",
          detail: a.description,
        });
      }
    }
    return items;
  });

  const seeAlso = computed<SeeAlsoItem[]>(() => {
    const t = termVal.value;
    if (!t?.related || !t?.official_concept) return [];
    const oc = t.official_concept;
    const ocVocab = refVocabOf(oc);
    return (t.related as any[])
      .filter(e => {
        const ref = e.ref;
        if (!ref) return false;
        if (ref.source === oc.source && ref.id === oc.id) return false;
        return refVocabOf(ref) === ocVocab;
      })
      .map(e => ({ ref: e.ref, url: vocabUrl(e.ref.source, e.ref.id) }));
  });

  return {
    fullConceptLang,
    fullConceptLangs,
    citedConcept,
    latestConcept,
    conceptData,
    conceptState,
    showConceptCard,
    canPropose,
    conceptVersions,
    conceptActions,
    seeAlso,
  };
}
