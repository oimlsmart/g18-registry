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
  return text.replace(/\{\{[^,}]+,([^}]+)\}\}/g, "$1").trim();
}
