export function kindLabel(k: string): string {
  return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—";
}

export function isHistoricTerm(term: { editions_present?: string[] } | string[]): boolean {
  const eds = Array.isArray(term) ? term : (term.editions_present || []);
  return eds.length > 0 && eds.every(e => e === "2010");
}

export function slugify(s: string): string {
  return (s || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

export function normalizeDef(text: string): string {
  return (text || "").replace(/\{\{[^,}]+,([^}]+)\}\}/g, "$1").trim();
}

export interface ProvenanceGroup {
  kind: string;
  relationship: string;
  ref: string;
  label: string;
  pubs: any[];
}

const PROVENANCE_RANK: Record<string, number> = {
  identical: 0, modified: 1, authoritative: 2, derived: 3, similar: 4, uncited: 5,
};
function formatRefSource(refSource: string, refId?: string): string {
  // Parse "OIML V 2-200:2012" → "VIM 2012", "OIML V 1-200:2022" → "VIML 2022"
  const m = refSource?.match(/V\s*(\d)-\d+:(\d{4})/);
  if (m) {
    const vocab = m[1] === "1" ? "VIML" : "VIM";
    return `${vocab} ${m[2]}${refId ? ` §${refId}` : ""}`;
  }
  return refSource || "";
}

export function provenanceLabel(s: any): string {
  if (!s) return "No VIM/VIML citation";
  const formatted = s.ref_source ? formatRefSource(s.ref_source, s.ref_id) : "";
  if (formatted) return formatted;
  const kl = ({ vim: "VIM", viml: "VIML", oiml_pub: "OIML document", other: "Other" } as Record<string, string>)[s.kind] || s.kind;
  return kl;
}

export function groupProvenance(publications: any[]): ProvenanceGroup[] {
  const groups = new Map<string, ProvenanceGroup>();
  for (const p of publications) {
    const s = p.source;
    if (!s) {
      const key = "oiml-original|uncited";
      const g = groups.get(key) || { kind: "oiml-original", relationship: "uncited", ref: "", label: "No VIM/VIML citation", pubs: [] };
      g.pubs.push(p);
      groups.set(key, g);
      continue;
    }
    const key = `${s.kind}|${s.relationship}|${s.ref_source || ""}`;
    const g = groups.get(key) || {
      kind: s.kind,
      relationship: s.relationship,
      ref: s.modification || "",
      label: provenanceLabel(s),
      pubs: [],
    };
    g.pubs.push(p);
    groups.set(key, g);
  }
  return Array.from(groups.values()).sort(
    (a, b) => (PROVENANCE_RANK[a.relationship] ?? 9) - (PROVENANCE_RANK[b.relationship] ?? 9) || b.pubs.length - a.pubs.length,
  );
}

export interface CrossEditionDrift {
  sameText: false;
  srcChanged: boolean;
  src2010: string | null;
  src202X: string | null;
  rel2010: string | null;
  rel202X: string | null;
}

export function computeCrossEditionDrift(publications: any[]): CrossEditionDrift | null {
  const editions = new Set(publications.map(p => p.edition));
  if (!(editions.has("2010") && editions.has("202X"))) return null;
  const e2010 = publications.filter(p => p.edition === "2010");
  const e202X = publications.filter(p => p.edition === "202X");
  const d2010 = new Set(e2010.map(p => normalizeDef(p.definition || "")).filter(Boolean));
  const d202X = new Set(e202X.map(p => normalizeDef(p.definition || "")).filter(Boolean));
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
}
