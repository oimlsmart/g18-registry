// Single source of truth for suggested-action data across all pages.
// Each page calls useSuggestedActions(terms) with the terms array and
// gets back filtered views for its audience.
//
// Action types (from Ruby G18::Actions::Compiler):
//   upgrade_vim / upgrade_viml — cite superseded edition
//   removed                    — not in latest edition
//   adopt_vim / adopt_viml     — could adopt from other vocabulary
//   harmonize                  — ≥ 2 distinct definitions
//   standardize                — all pubs identical, ready to confirm
//   unique                     — OIML-original, no VIM/VIML ref

import { computed, type ComputedRef } from "vue";

export interface SuggestedAction {
  type: string;
  priority: string;
  description: string;
  publication_ids: string[];
  vocab_ref?: Record<string, string>;
  slug: string;
  name: string;
}

export interface TermActionGroup {
  slug: string;
  name: string;
  actions: SuggestedAction[];
  priorityRank: number;
  pubCount: number;
}

const PRIORITY_RANK: Record<string, number> = {
  high: 0,
  medium: 1,
  info: 2,
  low: 3,
};

// Normalize publication IDs so spaced ("OIML R 76-1:2006") and compact
// ("OIML R076-1:2006") formats compare equal.
export function normalizePubId(id: string): string {
  return (id || "")
    .replace(/OIML\s+([RDGB])\s*/i, "OIML $1")  // "OIML R 76" → "OIML R76"
    .replace(/\s+/g, " ")
    .trim();
}

export function useSuggestedActions(terms: any[]) {
  const allActions: ComputedRef<SuggestedAction[]> = computed(() => {
    const out: SuggestedAction[] = [];
    for (const t of terms) {
      const slug = t.slug;
      const name = t.name;
      for (const a of t.suggested_actions || []) {
        out.push({ ...a, slug, name });
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

  // Group actions by term slug. Each group carries the highest-priority rank
  // across its actions (so a term with both a `removed:high` and a
  // `harmonize:low` action sorts as `high`). The publication count is the
  // union of publication_ids across all actions in the group.
  const byTerm: ComputedRef<TermActionGroup[]> = computed(() => {
    const map: Record<string, TermActionGroup> = {};
    for (const a of allActions.value) {
      let g = map[a.slug];
      if (!g) {
        g = { slug: a.slug, name: a.name, actions: [], priorityRank: 9, pubCount: 0 };
        map[a.slug] = g;
      }
      g.actions.push(a);
      g.priorityRank = Math.min(g.priorityRank, PRIORITY_RANK[a.priority] ?? 9);
      const ids = new Set(a.publication_ids || []);
      g.pubCount += ids.size;
    }
    return Object.values(map).sort((a, b) => {
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
