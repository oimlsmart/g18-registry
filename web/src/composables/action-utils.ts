import { slugify, isHistoricTerm, normalizeDef } from "@/utils/term-utils";

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

export const PRIORITY_RANK: Record<string, number> = {
  high: 0,
  medium: 1,
  info: 2,
  low: 3,
};

export interface ActionMeta {
  label: string;
  icon: string;
  hint: string;
  applies_to: string;
}

export const ACTION_META: Record<string, ActionMeta> = {
  upgrade_vim:  { label: "Update VIM ref",  icon: "↑", hint: "Cited VIM is superseded; the term exists in VIM 2012. Re-cite to current, or keep older citation with justification.", applies_to: "202X" },
  upgrade_viml: { label: "Update VIML ref", icon: "↑", hint: "Cited VIML is superseded; the term exists in VIML 2022. Re-cite to current, or keep older citation with justification.", applies_to: "202X" },
  removed:      { label: "Removed from VIM/VIML", icon: "⊘", hint: "Term is in the cited older edition but no longer in VIM 2012 / VIML 2022. Verify rename, reallocate, or justify retention.", applies_to: "202X" },
  adopt_vim:    { label: "Adopt from VIM",  icon: "←", hint: "OIML-original term that VIM also defines. Consider citing VIM as authoritative source.", applies_to: "202X" },
  adopt_viml:   { label: "Adopt from VIML", icon: "←", hint: "OIML-original term that VIML also defines. Consider citing VIML as authoritative source.", applies_to: "202X" },
  harmonize:    { label: "Harmonize",       icon: "⇄", hint: "≥ 2 publications under this TC/SC use different definitions for the same term. Decide: merge into one, or document why divergence is intentional.", applies_to: "all" },
  standardize:  { label: "Standardize",     icon: "≡", hint: "All citing publications already use identical wording. Batch-confirm as canonical for G 18:202X.", applies_to: "202X" },
  unique:       { label: "OIML-original",   icon: "★", hint: "Term has no VIM/VIML reference. Confirm OIML is the authoritative source.", applies_to: "all" },
};

export const ACTION_TYPES = Object.keys(ACTION_META);
export const ACTION_PRIORITIES = Object.keys(PRIORITY_RANK);

export function actionMeta(type: string): ActionMeta {
  return ACTION_META[type] || { label: type, icon: "•", hint: "", applies_to: "" };
}

export function isHistoric(term: { editions_present?: string[] }): boolean {
  return isHistoricTerm(term);
}

export function isOimlOriginal(term: { kind?: string }): boolean {
  const k = term?.kind;
  return k === "oiml_original" || k === "undefined";
}

export function maxWithinEditionDistinctDefs(pubs: any[]): number {
  const byEd: Record<string, Set<string>> = {};
  for (const p of pubs) {
    const d = normalizeDef(p?.definition || "");
    if (!d) continue;
    const ed = p.edition || "(unspecified)";
    if (!byEd[ed]) byEd[ed] = new Set();
    byEd[ed].add(d);
  }
  return Math.max(0, ...Object.values(byEd).map(s => s.size));
}

export function normalizePubId(id: string): string {
  return (id || "")
    .replace(/OIML\s+([RDGB])\s*/i, "OIML $1")
    .replace(/\s+/g, " ")
    .trim();
}

export function slugifyPubId(id: string): string {
  return slugify(id);
}
