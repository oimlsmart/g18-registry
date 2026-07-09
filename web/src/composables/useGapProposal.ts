// Composes a GitHub issue body for a vocabulary-gap proposal.
// The body is YAML front-matter (machine-parseable) plus a human-readable
// rationale section. A SHA-256 checksum over the front-matter guards
// against silent edits — reviewers can verify integrity.

import type { VocabGap } from "./useVocabGaps";

export type ProposalTarget = "V1" | "V2" | "V3";

export interface ProposalDraft {
  gap: VocabGap;
  target: ProposalTarget;
  rationale: string;
  author?: string;
}

// SHA-256 via the Web Crypto API. Returns hex.
async function sha256Hex(text: string): Promise<string> {
  if (typeof crypto === "undefined" || !crypto.subtle) {
    // SSR / non-secure context fallback: deterministic non-crypto hash.
    // (Only used during vite-ssg build; the live site uses crypto.subtle.)
    let h = 0;
    for (let i = 0; i < text.length; i++) {
      h = ((h << 5) - h) + text.charCodeAt(i);
      h |= 0;
    }
    return `fallback-${(h >>> 0).toString(16).padStart(8, "0")}`;
  }
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

function yamlQuote(s: string): string {
  // Single-quoted YAML. Escape single quotes by doubling them.
  return `'${String(s ?? "").replace(/'/g, "''")}'`;
}

export async function composeIssueBody(draft: ProposalDraft): Promise<string> {
  const { gap, target, rationale, author } = draft;
  const front: Record<string, any> = {
    kind: "vocabulary_gap_proposal",
    g18_term: gap.name,
    g18_identifier: gap.identifier,
    g18_slug: gap.slug,
    proposed_target: target,
    editions_present: gap.editions_present || [],
    publication_count: gap.publications.length,
    publication_ids: gap.publications.map(p => p.publication_id).sort(),
    near_misses: {
      vim: gap.near_misses?.vim ? {
        designation: gap.near_misses.vim.designation,
        concept_id: gap.near_misses.vim.concept_id,
        match_type: gap.near_misses.vim.match_type,
        similarity: gap.near_misses.vim.similarity ?? null,
      } : null,
      viml: gap.near_misses?.viml ? {
        designation: gap.near_misses.viml.designation,
        concept_id: gap.near_misses.viml.concept_id,
        match_type: gap.near_misses.viml.match_type,
        similarity: gap.near_misses.viml.similarity ?? null,
      } : null,
    },
    proposed_by: author || "",
  };
  // Render front-matter as YAML manually (the structure is flat enough).
  const yamlLines = [
    `kind: ${yamlQuote(front.kind)}`,
    `g18_term: ${yamlQuote(front.g18_term)}`,
    `g18_identifier: ${yamlQuote(front.g18_identifier)}`,
    `g18_slug: ${yamlQuote(front.g18_slug)}`,
    `proposed_target: ${yamlQuote(front.proposed_target)}`,
    `editions_present:`,
    ...front.editions_present.map((e: string) => `  - ${yamlQuote(e)}`),
    `publication_count: ${front.publication_count}`,
    `publication_ids:`,
    ...front.publication_ids.map((id: string) => `  - ${yamlQuote(id)}`),
    `near_misses:`,
    `  vim: ${front.near_misses.vim ? `{ designation: ${yamlQuote(front.near_misses.vim.designation)}, concept_id: ${yamlQuote(front.near_misses.vim.concept_id)}, match_type: ${yamlQuote(front.near_misses.vim.match_type)}, similarity: ${front.near_misses.vim.similarity ?? "null"} }` : "null"}`,
    `  viml: ${front.near_misses.viml ? `{ designation: ${yamlQuote(front.near_misses.viml.designation)}, concept_id: ${yamlQuote(front.near_misses.viml.concept_id)}, match_type: ${yamlQuote(front.near_misses.viml.match_type)}, similarity: ${front.near_misses.viml.similarity ?? "null"} }` : "null"}`,
    `proposed_by: ${yamlQuote(front.proposed_by)}`,
  ];
  const yamlBlock = yamlLines.join("\n");
  const checksum = await sha256Hex(yamlBlock);
  const body =
    `---\n${yamlBlock}\nchecksum: ${checksum}\n---\n\n` +
    `## Proposal\n\n` +
    `**${gap.name}** is proposed for inclusion in **${targetLabel(target)}**.\n\n` +
    `### Rationale\n\n${rationale.trim() || "(rationale to be filled in by proposer)"}\n\n` +
    `### G 18 definition(s)\n\n` +
    (gap.definitions.length
      ? gap.definitions.map((d, i) => `${i + 1}. ${d}`).join("\n")
      : "(no definition recorded in G 18)") +
    `\n\n### Near-miss candidates\n\n` +
    formatNearMiss("VIM", gap.near_misses?.vim) +
    formatNearMiss("VIML", gap.near_misses?.viml) +
    `\n### Publications using this term (${gap.publications.length})\n\n` +
    (gap.publications.length > 0
      ? gap.publications.slice(0, 20).map(p => `- ${p.publication_id} (${p.tc_sc || "—"}, ${p.edition})`).join("\n") +
        (gap.publications.length > 20 ? `\n- … and ${gap.publications.length - 20} more` : "")
      : "(none)") +
    `\n`;
  return body;
}

function formatNearMiss(label: string, nm: any): string {
  if (!nm) return `- **${label}**: no candidate match found\n`;
  const conf = nm.match_type === "exact" ? "exact match" : `fuzzy match (similarity ${nm.similarity})`;
  return `- **${label}**: ${nm.designation} (concept ${nm.concept_id}, ${conf})\n`;
}

export function targetLabel(t: ProposalTarget): string {
  return t === "V1" ? "VIML (V 1)" : t === "V2" ? "VIM (V 2)" : "V 3 (specific terms, draft)";
}

// Conceptual category metadata — leads with the user's mental model
// ("General concept in metrology") instead of the abstract V 1/V 2/V 3
// code. The code is kept as the canonical stored value (in YAML payload)
// but the UI surfaces the concept first.
export interface TargetCategory {
  code: ProposalTarget;
  concept: string;       // primary label, e.g. "General concept in metrology"
  target: string;        // secondary label, e.g. "Propose for VIM (V 2)"
  examples: string;      // helper text, e.g. "quantity, measuring instrument"
}

export const TARGET_CATEGORIES: TargetCategory[] = [
  {
    code: "V2",
    concept: "General concept in metrology",
    target: "Propose for VIM (V 2)",
    examples: "e.g. quantity, measuring instrument, accuracy",
  },
  {
    code: "V1",
    concept: "General concept in legal metrology",
    target: "Propose for VIML (V 1)",
    examples: "e.g. legal unit of measurement, type approval, verification",
  },
  {
    code: "V3",
    concept: "Specific term",
    target: "Propose for V 3 (new vocabulary)",
    examples: "e.g. load cell, set of weights, dosimeter, pressure gauge",
  },
];

export function categoryForTarget(t: ProposalTarget): TargetCategory {
  return TARGET_CATEGORIES.find(c => c.code === t) || TARGET_CATEGORIES[2];
}

export function composeIssueTitle(draft: ProposalDraft): string {
  const t = draft.target;
  const tgt = t === "V1" ? "VIML" : t === "V2" ? "VIM" : "V 3";
  return `Vocabulary proposal: "${draft.gap.name}" → ${tgt}`;
}

// Builds the GitHub "new issue" URL. The body is URL-encoded; users land
// on the issue-composer page with the title and body pre-filled.
export function composeIssueUrl(draft: ProposalDraft, body: string): string {
  const title = composeIssueTitle(draft);
  const params = new URLSearchParams({
    "title": title,
    "body": body,
  });
  return `https://github.com/oimlsmart/g18-registry/issues/new?${params.toString()}`;
}
