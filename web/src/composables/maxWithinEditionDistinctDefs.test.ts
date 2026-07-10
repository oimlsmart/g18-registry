import { describe, it, expect } from "vitest";
import { maxWithinEditionDistinctDefs } from "@/composables/useSuggestedActions";

// Tests the per-edition divergence detection used by the dashboard,
// harmonization worklist, and compiler logic. This is the CANONICAL
// helper — the Astro migration must preserve this behavior.

describe("maxWithinEditionDistinctDefs", () => {
  it("returns max distinct defs within a single edition", () => {
    const pubs = [
      { edition: "202X", definition: "def A" },
      { edition: "202X", definition: "def B" },
      { edition: "2010", definition: "def C" },
    ];
    expect(maxWithinEditionDistinctDefs(pubs)).toBe(2); // 202X has 2
  });

  it("does NOT count cross-edition differences as divergence", () => {
    const pubs = [
      { edition: "202X", definition: "202X wording" },
      { edition: "2010", definition: "2010 wording" },
    ];
    expect(maxWithinEditionDistinctDefs(pubs)).toBe(1); // each edition has 1
  });

  it("returns 1 when all pubs share the same definition", () => {
    const pubs = [
      { edition: "202X", definition: "same" },
      { edition: "2010", definition: "same" },
    ];
    expect(maxWithinEditionDistinctDefs(pubs)).toBe(1);
  });

  it("returns 0 for empty pubs", () => {
    expect(maxWithinEditionDistinctDefs([])).toBe(0);
  });

  it("handles missing definitions gracefully", () => {
    const pubs = [
      { edition: "202X", definition: "" },
      { edition: "202X", definition: "def A" },
    ];
    expect(maxWithinEditionDistinctDefs(pubs)).toBe(1); // only non-empty counts
  });

  it("handles multiple editions with different divergence counts", () => {
    const pubs = [
      { edition: "202X", definition: "A" },
      { edition: "202X", definition: "B" },
      { edition: "202X", definition: "C" },
      { edition: "2010", definition: "D" },
      { edition: "2010", definition: "E" },
    ];
    expect(maxWithinEditionDistinctDefs(pubs)).toBe(3); // 202X has 3
  });
});
