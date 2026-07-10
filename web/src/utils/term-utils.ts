export function kindLabel(k: string): string {
  return k === "defined_in_vim" ? "VIM" : k === "defined_in_viml" ? "VIML" : "—";
}

export function isHistoricTerm(editions: string[]): boolean {
  return editions.length > 0 && editions.every(e => e === "2010");
}

export function slugify(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}
