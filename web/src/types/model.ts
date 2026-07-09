// Domain types matching the Ruby model. Single source of truth for the
// data shape consumed by Vue components and composables.

// "oiml_original" is the canonical kind for terms with no VIM/VIML
// citation. "undefined" is the legacy value, kept for backward compat
// with data files written before the rename.
export type TermKind = "defined_in_vim" | "defined_in_viml" | "oiml_original" | "undefined";
export type ConsistencyLevel = "ok" | "partial" | "ko" | "pending";
export type EditionName = string;
export type VocabRole = "current" | "prior" | "legacy";
export type VocabName = "vim" | "viml";

export interface AuthorityRef {
  source: string;       // URN, e.g. "urn:oiml:pub:v:2:1993"
  id: string;           // concept ID, e.g. "5.7"
  url?: string;         // link to vocab site
  definition_text?: string;
  edition_label?: string;  // "VIM 1993"
  vocab?: string;          // "vim" | "viml"
  role?: string;           // "current" | "prior" | "legacy"
  year?: number;
}

export interface PublicationInstance {
  edition: string;
  publication: string;
  publication_id: string;
  tc_sc: string;
  year: number;
  clause: string;
  link: string;
  g18_entry: string;
  definition: string;
  notes: string[];
  consistency: ConsistencyLevel;
  consistency_reason: string;
  related?: Array<{ type: string; ref: AuthorityRef }>;
}

export interface RelatedEdge {
  type: string;
  ref: AuthorityRef;
}

export interface Term {
  slug: string;
  identifier: string;
  name: string;
  kind: TermKind;
  official_concept: AuthorityRef | null;
  editions_present: string[];
  primary_edition: string;
  publications: PublicationInstance[];
  related: RelatedEdge[];
}

export interface Publication {
  id: string;
  reference: string;
  link: string;
  tc_sc: string;
  year: number;
  notes: string;
}

export interface EditionStat {
  edition: string;
  primary: boolean;
  instances: number;
  terms: number;
  only_in_edition: number;
  harmonization_candidates: number;
}

export interface EditionStats {
  editions: string[];
  stats: EditionStat[];
  terms_in_both: number;
}

export interface ConflictEntry {
  id: string;
  concepts: Array<{ designation: string; source: string; raw_id: string }>;
}

export interface DesignationCollision {
  designation: string;
  ids: string[];
  count: number;
}

export interface ConflictData {
  raw: Record<string, ConflictEntry[]>;
  designation_collisions: Record<string, DesignationCollision[]>;
}
