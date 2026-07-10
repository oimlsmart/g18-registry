import { describe, it, expect } from "vitest";
import { useVocabGaps, vocabGaps, type VocabGap } from "@/composables/useVocabGaps";

// The vocabGaps data is loaded from JSON at import time. We test the
// shape and filtering logic, not the specific data values.

describe("useVocabGaps", () => {
  describe("vocabGaps data", () => {
    it("is a non-empty array", () => {
      expect(Array.isArray(vocabGaps)).toBe(true);
      expect(vocabGaps.length).toBeGreaterThan(0);
    });
    it("each gap has required fields", () => {
      for (const g of vocabGaps.slice(0, 10)) {
        expect(g.slug).toBeTruthy();
        expect(g.name).toBeTruthy();
        expect(g.definitions).toBeDefined();
        expect(g.publications).toBeDefined();
        expect(g.near_misses).toBeDefined();
        expect(g.near_misses.vim === null || typeof g.near_misses.vim === "object").toBe(true);
        expect(g.near_misses.viml === null || typeof g.near_misses.viml === "object").toBe(true);
      }
    });
  });

  describe("useVocabGaps composable", () => {
    it("provides allTCs list", () => {
      const { allTCs } = useVocabGaps();
      expect(allTCs.value.length).toBeGreaterThan(0);
      // Each TC should be a string like "TC9/SC1"
      for (const tc of allTCs.value.slice(0, 5)) {
        expect(typeof tc).toBe("string");
        expect(tc.length).toBeGreaterThan(0);
      }
    });

    it("filters by search query", () => {
      const { search, filtered } = useVocabGaps();
      search.value = vocabGaps[0].name.slice(0, 5).toLowerCase();
      const all = filtered.value.length;
      search.value = "zzzzzznomatch";
      expect(filtered.value.length).toBeLessThanOrEqual(all);
      search.value = "";
    });

    it("filters by scope = no-match (V 3 candidates)", () => {
      const { scope, filtered } = useVocabGaps();
      scope.value = "no-match";
      for (const g of filtered.value) {
        expect(g.near_misses.vim).toBeNull();
        expect(g.near_misses.viml).toBeNull();
      }
    });

    it("filters by scope = any-match (V 1/V 2 candidates)", () => {
      const { scope, filtered } = useVocabGaps();
      scope.value = "any-match";
      for (const g of filtered.value.slice(0, 10)) {
        expect(g.near_misses.vim || g.near_misses.viml).toBeTruthy();
      }
    });

    it("scope = all returns everything", () => {
      const { scope, filtered } = useVocabGaps();
      scope.value = "all";
      expect(filtered.value.length).toBe(vocabGaps.length);
    });
  });
});
