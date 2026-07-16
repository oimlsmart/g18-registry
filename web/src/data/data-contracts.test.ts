import { describe, it, expect } from "vitest";
import terms from "@/data/terms.json";
import termsSlim from "@/data/terms-slim.json";
import publications from "@/data/publications.json";
import vocabGaps from "@/data/vocab-gaps.json";
import conflicts from "@/data/conflicts.json";
import harmonization from "@/data/harmonization.json";
import editionStats from "@/data/edition-stats.json";
import tc from "@/data/tc.json";
import { ACTION_TYPES, ACTION_PRIORITIES } from "@/composables/useSuggestedActions";
import {
  termSchema, publicationSchema, vocabGapSchema, editionStatsSchema,
} from "@/data/schemas";

describe("data contract: terms.json (full schema validation)", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(terms)).toBe(true);
    expect(terms.length).toBeGreaterThan(0);
  });

  it("every term passes Zod schema validation (not just first 50)", () => {
    for (const t of terms) {
      const result = termSchema.safeParse(t);
      if (!result.success) {
        throw new Error(
          `Term "${t.slug}" failed validation: ${JSON.stringify(result.error.issues[0], null, 2)}`
        );
      }
    }
  });

  it("kind field uses known values", () => {
    const valid = ["oiml_original", "defined_in_vim", "defined_in_viml", "undefined"];
    for (const t of terms.slice(0, 50)) {
      expect(valid).toContain(t.kind);
    }
  });

  it("editions_present uses known values", () => {
    const valid = ["202X", "2010", "complete", "viml-2022", "viml-2013", "viml-2000", "vim-2012", "vim-2007", "vim-1993"];
    for (const t of terms.slice(0, 50)) {
      for (const e of t.editions_present) {
        expect(valid).toContain(e);
      }
    }
  });

  it("suggested_actions have type, priority, description, publication_ids", () => {
    const validTypes = ACTION_TYPES;
    const validPriorities = ACTION_PRIORITIES;
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

describe("data contract: terms-slim.json", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(termsSlim)).toBe(true);
    expect((termsSlim as any[]).length).toBeGreaterThan(0);
  });

  it("each entry has required fields", () => {
    for (const t of (termsSlim as any[]).slice(0, 20)) {
      expect(typeof t.slug).toBe("string");
      expect(typeof t.name).toBe("string");
      expect(Array.isArray(t.editions_present)).toBe(true);
    }
  });

  it("entries are consistent with terms.json", () => {
    for (const term of terms.slice(0, 20)) {
      const bySlug = (termsSlim as any[]).find(t => t.slug === term.slug);
      expect(bySlug).toBeDefined();
      expect(bySlug.name).toBe(term.name);
      expect(bySlug.identifier).toBe(term.identifier);
    }
  });
});

describe("data contract: publications.json (full schema validation)", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(publications)).toBe(true);
    expect(publications.length).toBeGreaterThan(0);
  });

  it("every publication passes Zod schema validation", () => {
    for (const p of publications) {
      const result = publicationSchema.safeParse(p);
      if (!result.success) {
        throw new Error(`Publication "${p.id}" failed: ${JSON.stringify(result.error.issues[0])}`);
      }
    }
  });

  it("ids are unique", () => {
    const ids = publications.map(p => p.id);
    const unique = new Set(ids);
    expect(unique.size).toBe(ids.length);
  });
});

describe("data contract: vocab-gaps.json (full schema validation)", () => {
  it("is a non-empty array", () => {
    expect(Array.isArray(vocabGaps)).toBe(true);
    expect(vocabGaps.length).toBeGreaterThan(0);
  });

  it("every gap passes Zod schema validation", () => {
    for (const g of vocabGaps) {
      const result = vocabGapSchema.safeParse(g);
      if (!result.success) {
        throw new Error(`Vocab gap "${g.slug}" failed: ${JSON.stringify(result.error.issues[0])}`);
      }
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

describe("data contract: edition-stats.json (full schema validation)", () => {
  it("passes Zod schema validation", () => {
    const result = editionStatsSchema.safeParse(editionStats);
    expect(result.success).toBe(true);
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
