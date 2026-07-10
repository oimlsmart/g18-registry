import termBySlug from "@/data/term-by-slug.json";

let conceptIdLookup: Record<string, string> | null = null;
let nameLookup: Record<string, string> | null = null;
let allSlugs: Set<string> | null = null;

function ensureLookups() {
  if (conceptIdLookup) return;
  conceptIdLookup = {};
  nameLookup = {};
  allSlugs = new Set();
  for (const [slug, term] of Object.entries(termBySlug as any)) {
    const id = (term as any).official_concept?.id;
    if (id && !conceptIdLookup![id]) conceptIdLookup![id] = slug;
    if ((term as any).name) nameLookup![(term as any).name.toLowerCase()] = slug;
    allSlugs.add(slug);
  }
}

function singularize(s: string): string {
  if (s.endsWith("ies")) return s.slice(0, -3) + "y";
  if (s.endsWith("s")) return s.slice(0, -1);
  return s;
}

function slugifyText(s: string): string {
  return s.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

export function resolveXrefSlug(conceptId: string, text: string): string | null {
  ensureLookups();
  if (conceptIdLookup![conceptId]) return conceptIdLookup![conceptId];
  const lower = text.trim().toLowerCase();
  if (nameLookup![lower]) return nameLookup![lower];
  const singular = singularize(lower);
  if (nameLookup![singular]) return nameLookup![singular];
  const textSlug = slugifyText(text);
  if (allSlugs!.has(textSlug)) return textSlug;
  return null;
}

export { singularize, slugifyText };
