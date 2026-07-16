import { computed, type ComputedRef } from "vue";
import {
  type SuggestedAction,
  type TermActionGroup,
  PRIORITY_RANK,
  normalizePubId,
} from "@/composables/action-utils";

// Returns action views over a list of terms. Each action becomes a
// SuggestedAction with the parent term's slug/name attached so UI rows
// can render and link without joining back to the terms list.
export function useSuggestedActions(terms: any[]) {
  const allActions: ComputedRef<SuggestedAction[]> = computed(() => {
    const out: SuggestedAction[] = [];
    for (const t of terms) {
      const slug = t.slug;
      const name = t.name;
      const editionsPresent = t.editions_present;
      for (const a of t.suggested_actions || []) {
        out.push({ ...a, slug, name, editionsPresent });
      }
    }
    return out;
  });

  const byType = computed(() => {
    const map: Record<string, SuggestedAction[]> = {};
    for (const a of allActions.value) {
      (map[a.type] ||= []).push(a);
    }
    return map;
  });

  const byTerm: ComputedRef<TermActionGroup[]> = computed(() => {
    const map: Record<string, TermActionGroup & { _allPubIds: Set<string> }> = {};
    for (const a of allActions.value) {
      let g = map[a.slug];
      if (!g) {
        const eds = a.editionsPresent || [];
        g = {
          slug: a.slug,
          name: a.name,
          actions: [],
          priorityRank: 9,
          pubCount: 0,
          isHistoric: eds.length > 0 && eds.every(e => e === "2010"),
          editionsPresent: eds,
          _allPubIds: new Set<string>(),
        };
        map[a.slug] = g;
      }
      g.actions.push(a);
      g.priorityRank = Math.min(g.priorityRank, PRIORITY_RANK[a.priority] ?? 9);
      for (const id of (a.publication_ids || [])) g._allPubIds.add(id);
    }
    return Object.values(map).map(({ _allPubIds, ...rest }) => ({
      ...rest,
      pubCount: _allPubIds.size,
    })).sort((a, b) => {
      if (a.isHistoric !== b.isHistoric) return a.isHistoric ? 1 : -1;
      if (a.priorityRank !== b.priorityRank) return a.priorityRank - b.priorityRank;
      return a.name.localeCompare(b.name);
    });
  });

  const counts = computed(() => {
    const c: Record<string, number> = {};
    for (const a of allActions.value) c[a.type] = (c[a.type] || 0) + 1;
    return c;
  });

  function forPublication(pubId: string): SuggestedAction[] {
    const norm = normalizePubId(pubId);
    return allActions.value.filter(a =>
      (a.publication_ids || []).some(id => normalizePubId(id) === norm)
    );
  }

  function forTCSC(tcSc: string): SuggestedAction[] {
    const pubIds = new Set<string>();
    for (const t of terms) {
      for (const p of t.publications || []) {
        if (p.tc_sc === tcSc) pubIds.add(normalizePubId(p.publication_id));
      }
    }
    return allActions.value.filter(a =>
      (a.publication_ids || []).some(id => pubIds.has(normalizePubId(id)))
    );
  }

  function forTerm(slug: string): SuggestedAction[] {
    return allActions.value.filter(a => a.slug === slug);
  }

  return { allActions, byType, byTerm, counts, forPublication, forTCSC, forTerm };
}
