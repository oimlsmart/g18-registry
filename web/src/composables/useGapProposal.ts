// Composes a GitHub issue body for a vocabulary-gap proposal.
//
// IMPORTANT: GitHub's `issues/new?body=...` URL has a practical length
// limit (~8K chars after URL encoding). Earlier versions embedded a
// full YAML front-matter (all publication_ids + near-miss objects +
// checksum) which easily blew past the limit for terms cited by 30+
// publications, causing the POST to silently fail.
//
// The body is now plain Markdown — no YAML, no checksum, capped lists.
// If machine-readable metadata is needed later, attach it via the GitHub
// API after the issue is created (separate authenticated request).

import type { VocabGap } from "./useVocabGaps";

export type ProposalTarget = "V1" | "V2" | "V3";

export interface ProposalDraft {
  gap: VocabGap;
  target: ProposalTarget;
  rationale: string;
  author?: string;
}

const MAX_PUBLICATIONS_IN_BODY = 10;

export async function composeIssueBody(draft: ProposalDraft): Promise<string> {
  const { gap, target, rationale, author } = draft;
  const pubs = gap.publications || [];
  const visiblePubs = pubs.slice(0, MAX_PUBLICATIONS_IN_BODY);
  const hiddenCount = Math.max(0, pubs.length - visiblePubs.length);

  const lines: string[] = [];
  lines.push(`## Proposal`);
  lines.push("");
  lines.push(`**${gap.name}** is proposed for inclusion in **${targetLabel(target)}**.`);
  if (author) lines.push(`_Proposed by ${author}._`);
  lines.push("");
  lines.push(`- **Slug**: \`${gap.slug}\``);
  if (gap.identifier) lines.push(`- **G 18 identifier**: ${gap.identifier}`);
  lines.push(`- **Cited in**: ${pubs.length} publication${pubs.length === 1 ? "" : "s"}`);
  lines.push("");

  lines.push(`### Rationale`);
  lines.push("");
  lines.push(rationale.trim() || "_(rationale to be filled in by proposer)_");
  lines.push("");

  if ((gap.definitions || []).length > 0) {
    lines.push(`### G 18 definition(s)`);
    lines.push("");
    gap.definitions.forEach((d, i) => lines.push(`${i + 1}. ${d}`));
    lines.push("");
  }

  lines.push(`### Near-miss candidates`);
  lines.push("");
  lines.push(formatNearMiss("VIM", gap.near_misses?.vim));
  lines.push(formatNearMiss("VIML", gap.near_misses?.viml));
  lines.push("");

  if (visiblePubs.length > 0) {
    lines.push(`### Publications using this term${hiddenCount > 0 ? ` (first ${MAX_PUBLICATIONS_IN_BODY} of ${pubs.length})` : ""}`);
    lines.push("");
    visiblePubs.forEach(p => {
      const tc = p.tc_sc ? ` · ${p.tc_sc}` : "";
      const ed = p.edition ? ` · ${p.edition}` : "";
      lines.push(`- ${p.publication_id}${tc}${ed}`);
    });
    if (hiddenCount > 0) lines.push(`- _…and ${hiddenCount} more_`);
    lines.push("");
  }

  return lines.join("\n");
}

function formatNearMiss(label: string, nm: any): string {
  if (!nm) return `- **${label}**: no candidate match found`;
  const conf = nm.match_type === "exact" ? "exact match" : `fuzzy match (similarity ${nm.similarity ?? "?"})`;
  return `- **${label}**: ${nm.designation} (concept ${nm.concept_id}, ${conf})`;
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
    code: "V1",
    concept: "General concept in legal metrology",
    target: "Propose for next VIML edition (V 1)",
    examples: "e.g. legal unit of measurement, type approval, verification",
  },
  {
    code: "V2",
    concept: "General concept in metrology",
    target: "Propose for next VIM edition (V 2)",
    examples: "e.g. quantity, measuring instrument, accuracy",
  },
  {
    code: "V3",
    concept: "Specific term",
    target: "Propose for new V 3 vocabulary",
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
  return `https://github.com/oimlsmart/concepts-management/issues/new?${params.toString()}`;
}
