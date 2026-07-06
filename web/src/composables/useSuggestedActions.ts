// Single source of truth for suggested-action data across all pages.
// Each page calls useSuggestedActions(terms) with the terms array and
// gets back filtered views for its audience.
//
// Action types (from Ruby G18::Actions::Compiler):
//   upgrade_vim / upgrade_viml — cite superseded edition (label: "Update")
//   removed                    — not in latest edition (label: "Removed from VIM/VIML")
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
  editionsPresent?: string[];
}

export interface TermActionGroup {
  slug: string;
  name: string;
  actions: SuggestedAction[];
  priorityRank: number;
  pubCount: number;
  isHistoric: boolean;
  editionsPresent: string[];
}

const PRIORITY_RANK: Record<string, number> = {
  high: 0,
  medium: 1,
  info: 2,
  low: 3,
};

// Canonical action metadata — used by every page that renders actions.
// Pages should NOT hard-code type labels; import from here so a rename
// (or icon swap) propagates everywhere.
export interface ActionMeta {
  label: string;       // short name for filter buttons, e.g. "Update VIM"
  icon: string;        // single Unicode glyph
  hint: string;        // one-line "what decision does TC 1 need to make?"
  applies_to: string;  // "202X only" / "all editions"
}
export const ACTION_META: Record<string, ActionMeta> = {
  upgrade_vim:  { label: "Update VIM ref",  icon: "↑", hint: "Cited VIM is superseded; the term exists in VIM 2012. Re-cite to current, or keep older citation with justification.", applies_to: "202X only" },
  upgrade_viml: { label: "Update VIML ref", icon: "↑", hint: "Cited VIML is superseded; the term exists in VIML 2022. Re-cite to current, or keep older citation with justification.", applies_to: "202X only" },
  removed:      { label: "Removed from VIM/VIML", icon: "⊘", hint: "Term is in the cited older edition but no longer in VIM 2012 / VIML 2022. Verify rename, reallocate, or justify retention.", applies_to: "202X only" },
  adopt_vim:    { label: "Adopt from VIM",  icon: "←", hint: "OIML-original term that VIM also defines. Consider citing VIM as authoritative source.", applies_to: "202X only" },
  adopt_viml:   { label: "Adopt from VIML", icon: "←", hint: "OIML-original term that VIML also defines. Consider citing VIML as authoritative source.", applies_to: "202X only" },
  harmonize:    { label: "Harmonize",       icon: "⇄", hint: "≥ 2 publications under this TC/SC use different definitions for the same term. Decide: merge into one, or document why divergence is intentional.", applies_to: "all editions" },
  standardize:  { label: "Standardize",     icon: "≡", hint: "All citing publications already use identical wording. Batch-confirm as canonical for G 18:202X.", applies_to: "202X only" },
  unique:       { label: "OIML-original",   icon: "★", hint: "Term has no VIM/VIML reference. Confirm OIML is the authoritative source.", applies_to: "all editions" },
};

export function actionMeta(type: string): ActionMeta {
  return ACTION_META[type] || { label: type, icon: "•", hint: "", applies_to: "" };
}

// A term is "historic" when it appears only in the 2010 edition — TC 1
// cannot act on these (2010 is published). We keep them visible in
// worklists for completeness but visually deprioritize them.
export function isHistoric(term: { editions_present?: string[] }): boolean {
  const eds = term?.editions_present || [];
  return eds.length > 0 && eds.every(e => e === "2010");
}

// Normalize publication IDs so spaced ("OIML R 76-1:2006") and compact
// ("OIML R076-1:2006") formats compare equal.
export function normalizePubId(id: string): string {
  return (id || "")
    .replace(/OIML\s+([RDGB])\s*/i, "OIML $1")  // "OIML R 76" → "OIML R76"
    .replace(/\s+/g, " ")
    .trim();
}

// Deterministic URL-safe slug for publication IDs.
// "OIML R 76-1:2006" → "oiml-r-76-1-2006"
// Lowercase, replace any non-alphanumeric run with a single dash, trim.
// Stable and reversible (we keep a reverse map in the publication detail
// page so old raw-ID links still resolve).
export function slugifyPubId(id: string): string {
  return (id || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

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

  // Group actions by term slug. Each group carries the highest-priority rank
  // across its actions (so a term with both a `removed:high` and a
  // `harmonize:low` action sorts as `high`). The publication count is the
  // union of publication_ids across all actions in the group. Historic
  // (2010-only) terms are flagged so pages can deprioritize their rows.
  const byTerm: ComputedRef<TermActionGroup[]> = computed(() => {
    const map: Record<string, TermActionGroup> = {};
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
        };
        map[a.slug] = g;
      }
      g.actions.push(a);
      g.priorityRank = Math.min(g.priorityRank, PRIORITY_RANK[a.priority] ?? 9);
      const ids = new Set(a.publication_ids || []);
      g.pubCount += ids.size;
    }
    return Object.values(map).sort((a, b) => {
      // Historic terms sink below non-historic at same priority.
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
