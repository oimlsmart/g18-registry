import { describe, it, expect } from "vitest";
import terms from "@/data/terms.json";
import termBySlug from "@/data/term-by-slug.json";
import publications from "@/data/publications.json";
import vocabGaps from "@/data/vocab-gaps.json";
import conflicts from "@/data/conflicts.json";
import harmonization from "@/data/harmonization.json";
import editionStats from "@/data/edition-stats.json";
import tc from "@/data/tc.json";

describe("data contract: terms.json", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(terms)).toBe(true);
    expect(terms.length).toBeGreaterThan(0);
  });

  it("each term has required top-level fields", () => {
    for (const t of terms.slice(0, 50)) {
      expect(typeof t.slug).toBe("string");
      expect(t.slug.length).toBeGreaterThan(0);
      expect(typeof t.identifier).toBe("string");
      expect(typeof t.name).toBe("string");
      expect(Array.isArray(t.designations)).toBe(true);
      expect(Array.isArray(t.editions_present)).toBe(true);
      expect(Array.isArray(t.suggested_actions)).toBe(true);
      expect(Array.isArray(t.publications)).toBe(true);
    }
  });

  it("kind field uses known values", () => {
    const valid = ["oiml_original", "defined_in_vim", "defined_in_viml", "undefined"];
    for (const t of terms.slice(0, 50)) {
      expect(valid).toContain(t.kind);
    }
  });

  it("editions_present uses known values", () => {
    const valid = ["202X", "2010"];
    for (const t of terms.slice(0, 50)) {
      for (const e of t.editions_present) {
        expect(valid).toContain(e);
      }
    }
  });

  it("suggested_actions have type, priority, description, publication_ids", () => {
    const validTypes = ["upgrade_vim", "upgrade_viml", "removed", "adopt_vim", "adopt_viml", "harmonize", "standardize", "unique"];
    const validPriorities = ["high", "medium", "low", "info"];
    for (const t of terms.slice(0, 50)) {
      for (const a of t.suggested_actions) {
        expect(validTypes).toContain(a.type);
        expect(validPriorities).toContain(a.priority);
        expect(typeof a.description).toBe("string");
        expect(Array.isArray(a.publication_ids)).toBe(true);
      }
    }
  });

  it("publications have required sub-fields", () => {
    for (const t of terms.slice(0, 50)) {
      for (const p of t.publications) {
        expect(typeof p.publication_id).toBe("string");
        expect(typeof p.edition).toBe("string");
        expect(p.definition !== undefined).toBe(true);
      }
    }
  });
});

describe("data contract: term-by-slug.json", () => {
  it("is a non-empty object keyed by slug", () => {
    expect(typeof termBySlug).toBe("object");
    expect(termBySlug).not.toBeNull();
    expect(Object.keys(termBySlug).length).toBeGreaterThan(0);
  });

  it("each entry has the same shape as terms.json entries", () => {
    const keys = Object.keys(termBySlug).slice(0, 20);
    for (const slug of keys) {
      const t = (termBySlug as any)[slug];
      expect(t.slug).toBe(slug);
      expect(typeof t.name).toBe("string");
      expect(Array.isArray(t.designations)).toBe(true);
      expect(Array.isArray(t.publications)).toBe(true);
    }
  });

  it("entries are consistent with terms.json", () => {
    for (const term of terms.slice(0, 20)) {
      const bySlug = (termBySlug as any)[term.slug];
      expect(bySlug).toBeDefined();
      expect(bySlug.name).toBe(term.name);
      expect(bySlug.identifier).toBe(term.identifier);
    }
  });
});

describe("data contract: publications.json", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(publications)).toBe(true);
    expect(publications.length).toBeGreaterThan(0);
  });

  it("each publication has id, reference, link, tc_sc", () => {
    for (const p of publications.slice(0, 50)) {
      expect(typeof p.id).toBe("string");
      expect(p.id.length).toBeGreaterThan(0);
      expect(typeof p.reference).toBe("string");
      expect(typeof p.link).toBe("string");
    }
  });

  it("ids are unique", () => {
    const ids = publications.map(p => p.id);
    const unique = new Set(ids);
    expect(unique.size).toBe(ids.length);
  });
});

describe("data contract: vocab-gaps.json", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(vocabGaps)).toBe(true);
    expect(vocabGaps.length).toBeGreaterThan(0);
  });

  it("each gap has slug, name, definitions, publications, near_misses", () => {
    for (const g of vocabGaps.slice(0, 20)) {
      expect(typeof g.slug).toBe("string");
      expect(typeof g.name).toBe("string");
      expect(Array.isArray(g.definitions)).toBe(true);
      expect(g.near_misses).toBeDefined();
      expect(typeof g.near_misses).toBe("object");
    }
  });

  it("near_misses.vim and near_misses.viml are null or objects", () => {
    for (const g of vocabGaps.slice(0, 20)) {
      expect(g.near_misses.vim === null || typeof g.near_misses.vim === "object").toBe(true);
      expect(g.near_misses.viml === null || typeof g.near_misses.viml === "object").toBe(true);
    }
  });

  it("some gaps have V 1/V 2 near-misses and some don't", () => {
    const withMatch = vocabGaps.filter(g => g.near_misses.vim || g.near_misses.viml);
    const withoutMatch = vocabGaps.filter(g => !g.near_misses.vim && !g.near_misses.viml);
    expect(withMatch.length).toBeGreaterThan(0);
    expect(withoutMatch.length).toBeGreaterThan(0);
  });
});

describe("data contract: conflicts.json", () => {
  it("is an object with raw key", () => {
    expect(typeof conflicts).toBe("object");
    expect(conflicts.raw).toBeDefined();
    expect(typeof conflicts.raw).toBe("object");
  });

  it("raw contains edition arrays with concept conflicts", () => {
    const editions = Object.keys(conflicts.raw);
    expect(editions.length).toBeGreaterThan(0);
    for (const ed of editions) {
      const arr = conflicts.raw[ed];
      expect(Array.isArray(arr)).toBe(true);
    }
  });

  it("each conflict has id and concepts array", () => {
    for (const ed of Object.keys(conflicts.raw)) {
      for (const c of conflicts.raw[ed].slice(0, 10)) {
        expect(typeof c.id).toBe("string");
        expect(Array.isArray(c.concepts)).toBe(true);
        expect(c.concepts.length).toBeGreaterThan(1);
      }
    }
  });
});

describe("data contract: harmonization.json", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(harmonization)).toBe(true);
    expect(harmonization.length).toBeGreaterThan(0);
  });

  it("each entry has slug, name, designations, kind, publications", () => {
    for (const h of harmonization.slice(0, 20)) {
      expect(typeof h.slug).toBe("string");
      expect(typeof h.name).toBe("string");
      expect(Array.isArray(h.designations)).toBe(true);
      expect(typeof h.kind).toBe("string");
      expect(Array.isArray(h.publications)).toBe(true);
    }
  });
});

describe("data contract: edition-stats.json", () => {
  it("has editions array, stats array, terms_in_both", () => {
    expect(Array.isArray(editionStats.editions)).toBe(true);
    expect(editionStats.editions.length).toBeGreaterThanOrEqual(2);
    expect(Array.isArray(editionStats.stats)).toBe(true);
    expect(typeof editionStats.terms_in_both).toBe("number");
  });

  it("stats entries have required numeric fields", () => {
    for (const s of editionStats.stats) {
      expect(typeof s.edition).toBe("string");
      expect(typeof s.terms).toBe("number");
      expect(typeof s.instances).toBe("number");
      expect(typeof s.only_in_edition).toBe("number");
      expect(typeof s.harmonization_candidates).toBe("number");
    }
  });
});

describe("data contract: tc.json", () => {
  it("is a non-empty array of strings", () => {
    expect(Array.isArray(tc)).toBe(true);
    expect(tc.length).toBeGreaterThan(0);
    for (const t of tc) {
      expect(typeof t).toBe("string");
      expect(t.length).toBeGreaterThan(0);
    }
  });

  it("contains known TC/SC codes", () => {
    expect(tc).toContain("TC9");
    expect(tc.some(t => t.startsWith("TC"))).toBe(true);
  });
});
