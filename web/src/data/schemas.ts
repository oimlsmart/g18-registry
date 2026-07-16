import { z } from "zod";

export const designationSchema = z.object({
  type: z.string(),
  status: z.string().optional(),
  text: z.string(),
  usage_info: z.string().nullable().optional(),
  field: z.string().nullable().optional(),
  international: z.boolean().optional(),
});

export const publicationInstanceSchema = z.object({
  edition: z.string().nullable().optional(),
  publication: z.string().nullable().optional(),
  publication_id: z.string().nullable().optional(),
  definition: z.string().nullable().optional(),
}).passthrough();

export const suggestedActionSchema = z.object({
  type: z.string(),
  priority: z.string(),
  description: z.string(),
  publication_ids: z.array(z.any()),
  vocab_ref: z.any().optional(),
}).passthrough();

export const officialConceptSchema = z.object({
  source: z.string(),
  id: z.string(),
  url: z.string().optional(),
  definition_text: z.string().optional(),
  edition_label: z.string().optional(),
  vocab: z.string().optional(),
  role: z.string().optional(),
  year: z.number().optional(),
  cited_concept: z.record(z.any()).nullable().optional(),
  latest_concept: z.record(z.any()).nullable().optional(),
  full_concept: z.record(z.any()).nullable().optional(),
}).nullable();

export const latestCheckSchema = z.object({
  found: z.boolean(),
  vocab: z.string().optional(),
  latest_label: z.string().optional(),
  latest_urn: z.string().optional(),
  concept_id: z.string().optional(),
  url: z.string().optional(),
}).nullable().optional();

export const termSchema = z.object({
  slug: z.string().min(1),
  identifier: z.string(),
  name: z.string(),
  designations: z.array(designationSchema),
  kind: z.string(),
  official_concept: officialConceptSchema.optional(),
  latest_check: latestCheckSchema.optional(),
  editions_present: z.array(z.string()),
  primary_edition: z.string().optional(),
  suggested_actions: z.array(suggestedActionSchema),
  publications: z.array(publicationInstanceSchema),
  related: z.array(z.any()).optional(),
  canonical_mismatch: z.any().optional(),
});

export const publicationSchema = z.object({
  id: z.string().min(1),
  reference: z.string().optional(),
  link: z.string().nullable().optional(),
  tc_sc: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
});

export const vocabGapSchema = z.object({
  slug: z.string().min(1),
  name: z.string(),
  identifier: z.string().optional(),
  definitions: z.array(z.string()),
  publications: z.array(z.any()),
  near_misses: z.object({
    vim: z.any().nullable(),
    viml: z.any().nullable(),
  }),
});

export const editionStatSchema = z.object({
  edition: z.string(),
  primary: z.boolean().optional(),
  instances: z.number(),
  terms: z.number(),
  only_in_edition: z.number(),
  harmonization_candidates: z.number(),
});

export const editionStatsSchema = z.object({
  editions: z.array(z.string()),
  stats: z.array(editionStatSchema),
  terms_in_both: z.number(),
});

// ── Dashboard (homepage summary) ───────────────────────────────────────
export const dashboardSchema = z.object({
  total_terms: z.number(),
  total_publications: z.number(),
  kind_counts: z.record(z.string(), z.number()),
  edition_counts: z.record(z.string(), z.number()).optional(),
  gaps_viml_near_miss: z.number(),
  gaps_vim_near_miss: z.number(),
  gaps_no_match: z.number(),
  priority_terms: z.array(z.object({
    slug: z.string(),
    name: z.string(),
    actions: z.array(z.string()),
    priority_rank: z.number(),
    pub_count: z.number(),
  })).optional(),
  pub_current: z.number(),
  pub_retired: z.number(),
  pub_withdrawn: z.number(),
  concepts_from_current: z.number().optional(),
  concepts_from_historic: z.number().optional(),
  alignment_counts: z.record(z.string(), z.number()),
});

// ── Conflicts (raw ID conflicts + designation collisions) ──────────────
export const conflictsSchema = z.object({
  raw: z.record(
    z.string(), // edition name
    z.array(z.object({
      id: z.string(),
      concepts: z.array(z.object({
        designation: z.string(),
        source: z.string().nullable().optional(),
        raw_id: z.string().nullable().optional(),
      })),
    })),
  ),
  designation_collisions: z.record(
    z.string(), // edition name
    z.array(z.object({
      designation: z.string(),
      ids: z.array(z.string()),
      count: z.number(),
    })),
  ),
});

// ── Harmonization candidates (terms with > 1 publication) ─────────────
export const harmonizationSchema = z.object({
  slug: z.string(),
  name: z.string(),
  kind: z.string(),
  identifier: z.string().nullable().optional(),
  publications: z.array(publicationInstanceSchema),
}).passthrough();

// ── Slim term (list / count pages — subset of term fields) ─────────────
export const termSlimSchema = z.object({
  slug: z.string(),
  name: z.string(),
  kind: z.string(),
  identifier: z.string().nullable().optional(),
  editions_present: z.array(z.string()),
  pub_count: z.number(),
  pub_ids: z.array(z.string()),
  tc_scs: z.array(z.string()),
  tc_counts: z.record(z.string(), z.number()),
  distinct_def_count: z.number(),
  action_types: z.array(z.string()),
  designations: z.array(designationSchema),
  official_concept_id: z.string().nullable().optional(),
  has_withdrawn: z.boolean().optional(),
  alignment_case: z.number().nullable().optional(),
  alignment_status: z.string().nullable().optional(),
});
