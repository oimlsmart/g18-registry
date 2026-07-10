import { describe, it, expect } from "vitest";
import {
  useSuggestedActions,
  ACTION_META,
  ACTION_TYPES,
  actionMeta,
  isHistoric,
  isOimlOriginal,
  slugifyPubId,
  normalizePubId,
  maxWithinEditionDistinctDefs,
} from "@/composables/useSuggestedActions";

const makeTerm = (overrides: any = {}) => ({
  slug: "test-term",
  name: "test term",
  kind: "oiml_original",
  editions_present: ["202X", "2010"],
  publications: [
    { publication_id: "OIML R 76-1:2006", edition: "202X", definition: "def A", tc_sc: "TC9/SC1" },
    { publication_id: "OIML R 76-1:2006", edition: "2010", definition: "def A", tc_sc: "TC9/SC1" },
  ],
  suggested_actions: [],
  ...overrides,
});

describe("useSuggestedActions", () => {
  it("flattens all actions across terms into allActions", () => {
    const terms = [
      makeTerm({ slug: "a", suggested_actions: [{ type: "harmonize", priority: "low", description: "x", publication_ids: ["P1"] }] }),
      makeTerm({ slug: "b", suggested_actions: [
        { type: "removed", priority: "high", description: "y", publication_ids: ["P2"] },
        { type: "unique", priority: "info", description: "z", publication_ids: ["P2"] },
      ]}),
    ];
    const { allActions } = useSuggestedActions(terms);
    expect(allActions.value).toHaveLength(3);
    expect(allActions.value[0].slug).toBe("a");
    expect(allActions.value[1].slug).toBe("b");
  });

  it("groups actions by term slug in byTerm", () => {
    const terms = [
      makeTerm({ slug: "a", suggested_actions: [
        { type: "harmonize", priority: "low", description: "x", publication_ids: ["P1", "P2"] },
        { type: "unique", priority: "info", description: "z", publication_ids: ["P1"] },
      ]}),
    ];
    const { byTerm } = useSuggestedActions(terms);
    expect(byTerm.value).toHaveLength(1);
    expect(byTerm.value[0].actions).toHaveLength(2);
    expect(byTerm.value[0].pubCount).toBe(2); // union of P1+P2
  });

  it("computes pubCount as union (not sum) across actions", () => {
    const terms = [
      makeTerm({ slug: "a", suggested_actions: [
        { type: "harmonize", priority: "low", description: "x", publication_ids: ["P1", "P2"] },
        { type: "removed", priority: "high", description: "y", publication_ids: ["P1", "P3"] },
      ]}),
    ];
    const { byTerm } = useSuggestedActions(terms);
    expect(byTerm.value[0].pubCount).toBe(3); // P1+P2+P3 deduped
  });

  it("takes max priority across actions in a group", () => {
    const terms = [
      makeTerm({ slug: "a", suggested_actions: [
        { type: "harmonize", priority: "low", description: "x", publication_ids: ["P1"] },
        { type: "removed", priority: "high", description: "y", publication_ids: ["P1"] },
      ]}),
    ];
    const { byTerm } = useSuggestedActions(terms);
    expect(byTerm.value[0].priorityRank).toBe(0); // high = 0
  });

  it("flags historic (2010-only) terms", () => {
    const terms = [
      makeTerm({ slug: "a", editions_present: ["2010"], suggested_actions: [
        { type: "harmonize", priority: "high", description: "x", publication_ids: ["P1"] },
      ]}),
      makeTerm({ slug: "b", editions_present: ["202X", "2010"], suggested_actions: [
        { type: "harmonize", priority: "high", description: "x", publication_ids: ["P1"] },
      ]}),
    ];
    const { byTerm } = useSuggestedActions(terms);
    const a = byTerm.value.find(g => g.slug === "a");
    const b = byTerm.value.find(g => g.slug === "b");
    expect(a?.isHistoric).toBe(true);
    expect(b?.isHistoric).toBe(false);
  });

  it("sorts historic terms below non-historic at same priority", () => {
    const terms = [
      makeTerm({ slug: "hist", editions_present: ["2010"], name: "historic", suggested_actions: [
        { type: "harmonize", priority: "high", description: "x", publication_ids: ["P1"] },
      ]}),
      makeTerm({ slug: "act", editions_present: ["202X"], name: "actionable", suggested_actions: [
        { type: "harmonize", priority: "high", description: "x", publication_ids: ["P1"] },
      ]}),
    ];
    const { byTerm } = useSuggestedActions(terms);
    expect(byTerm.value[0].slug).toBe("act");
    expect(byTerm.value[1].slug).toBe("hist");
  });

  it("counts actions by type", () => {
    const terms = [
      makeTerm({ slug: "a", suggested_actions: [
        { type: "harmonize", priority: "low", description: "x", publication_ids: ["P1"] },
        { type: "unique", priority: "info", description: "z", publication_ids: ["P1"] },
      ]}),
      makeTerm({ slug: "b", suggested_actions: [
        { type: "harmonize", priority: "high", description: "y", publication_ids: ["P2"] },
      ]}),
    ];
    const { counts } = useSuggestedActions(terms);
    expect(counts.value.harmonize).toBe(2);
    expect(counts.value.unique).toBe(1);
  });

  it("filters actions by publication", () => {
    const terms = [
      makeTerm({ slug: "a", suggested_actions: [
        { type: "harmonize", priority: "low", description: "x", publication_ids: ["OIML R 76-1:2006"] },
      ]}),
      makeTerm({ slug: "b", suggested_actions: [
        { type: "removed", priority: "high", description: "y", publication_ids: ["OIML R 50-1:2014"] },
      ]}),
    ];
    const { forPublication } = useSuggestedActions(terms);
    const result = forPublication("OIML R 76-1:2006");
    expect(result).toHaveLength(1);
    expect(result[0].slug).toBe("a");
  });

  it("filters actions by TC/SC", () => {
    const terms = [
      makeTerm({ slug: "a", publications: [
        { publication_id: "P1", tc_sc: "TC9/SC1", edition: "202X" },
      ], suggested_actions: [
        { type: "harmonize", priority: "low", description: "x", publication_ids: ["P1"] },
      ]}),
      makeTerm({ slug: "b", publications: [
        { publication_id: "P2", tc_sc: "TC10/SC1", edition: "202X" },
      ], suggested_actions: [
        { type: "removed", priority: "high", description: "y", publication_ids: ["P2"] },
      ]}),
    ];
    const { forTCSC } = useSuggestedActions(terms);
    const result = forTCSC("TC9/SC1");
    expect(result).toHaveLength(1);
    expect(result[0].slug).toBe("a");
  });
});

describe("ACTION_META", () => {
  it("has metadata for all known action types", () => {
    for (const t of ACTION_TYPES) {
      expect(ACTION_META[t]).toBeDefined();
      expect(ACTION_META[t].label).toBeTruthy();
      expect(ACTION_META[t].icon).toBeTruthy();
      expect(ACTION_META[t].hint).toBeTruthy();
      expect(ACTION_META[t].applies_to).toBeTruthy();
    }
  });

  it("applies_to uses values matching EditionFilter (not '202X only')", () => {
    for (const [type, meta] of Object.entries(ACTION_META)) {
      expect(["202X", "2010", "all"]).toContain(meta.applies_to);
    }
  });

  it("returns fallback for unknown type", () => {
    const m = actionMeta("unknown");
    expect(m.label).toBe("unknown");
    expect(m.icon).toBe("•");
  });
});

describe("isHistoric", () => {
  it("returns true for 2010-only terms", () => {
    expect(isHistoric({ editions_present: ["2010"] })).toBe(true);
  });
  it("returns false for terms in both editions", () => {
    expect(isHistoric({ editions_present: ["2010", "202X"] })).toBe(false);
  });
  it("returns false for 202X-only terms", () => {
    expect(isHistoric({ editions_present: ["202X"] })).toBe(false);
  });
  it("returns false for empty editions_present", () => {
    expect(isHistoric({ editions_present: [] })).toBe(false);
  });
});

describe("isOimlOriginal", () => {
  it("returns true for kind=oiml_original", () => {
    expect(isOimlOriginal({ kind: "oiml_original" })).toBe(true);
  });
  it("returns true for legacy kind=undefined", () => {
    expect(isOimlOriginal({ kind: "undefined" })).toBe(true);
  });
  it("returns false for defined terms", () => {
    expect(isOimlOriginal({ kind: "defined_in_vim" })).toBe(false);
    expect(isOimlOriginal({ kind: "defined_in_viml" })).toBe(false);
  });
});

describe("slugifyPubId", () => {
  it("slugifies publication IDs correctly", () => {
    expect(slugifyPubId("OIML R 76-1:2006")).toBe("oiml-r-76-1-2006");
    expect(slugifyPubId("OIML D 11:2004")).toBe("oiml-d-11-2004");
    expect(slugifyPubId("OIML B 3:2003")).toBe("oiml-b-3-2003");
  });
});

describe("normalizePubId", () => {
  it("normalizes space after letter in publication IDs", () => {
    expect(normalizePubId("OIML R 76-1:2006")).toBe("OIML R76-1:2006");
  });
});
