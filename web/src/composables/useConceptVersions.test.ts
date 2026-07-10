import { describe, it, expect } from "vitest";
import { computed } from "vue";
import { useConceptVersions } from "@/composables/useConceptVersions";

const makeTerm = (overrides: any = {}) => ({
  slug: "test-term",
  name: "test term",
  kind: "defined_in_vim",
  official_concept: {
    source: "urn:oiml:pub:v:2:1993",
    id: "5.24",
    edition_label: "VIM 1993",
    definition_text: "test definition",
    cited_concept: { eng: { designations: [{ type: "expression", status: "preferred", text: "test term" }], definitions: ["test def"], notes: [], examples: [] } },
    ...overrides.official_concept,
  },
  latest_check: { found: false, latest_label: "VIM 2012", latest_urn: "urn:oiml:pub:v:2:2012" },
  suggested_actions: [],
  related: [],
  ...overrides,
});

describe("useConceptVersions", () => {
  it("returns none state for oiml_original terms", () => {
    const term = computed(() => makeTerm({ kind: "oiml_original", official_concept: null }));
    const { conceptState, showConceptCard, conceptVersions } = useConceptVersions(term, computed(() => 1));
    expect(conceptState.value).toBe("none");
    expect(showConceptCard.value).toBe(false);
    expect(conceptVersions.value).toHaveLength(0);
  });

  it("returns removed state when latest_check.found is false", () => {
    const term = computed(() => makeTerm());
    const { conceptState } = useConceptVersions(term, computed(() => 1));
    expect(conceptState.value).toBe("removed");
  });

  it("returns current state when latest_check.found is true and IDs match", () => {
    const term = computed(() => makeTerm({
      latest_check: { found: true, concept_id: "5.24", latest_label: "VIM 2012" },
    }));
    const { conceptState } = useConceptVersions(term, computed(() => 1));
    expect(conceptState.value).toBe("current");
  });

  it("returns upgrade state when concept IDs differ", () => {
    const term = computed(() => makeTerm({
      official_concept: {
        source: "urn:oiml:pub:v:2:1993",
        id: "5.24",
        edition_label: "VIM 1993",
        cited_concept: { eng: { definitions: ["old"] } },
        latest_concept: { eng: { definitions: ["new"] } },
      },
      latest_check: { found: true, concept_id: "5.25", latest_label: "VIM 2012" },
    }));
    const { conceptState, conceptVersions } = useConceptVersions(term, computed(() => 1));
    expect(conceptState.value).toBe("upgrade");
    expect(conceptVersions.value).toHaveLength(2);
    expect(conceptVersions.value[0].status).toBe("superseded");
    expect(conceptVersions.value[1].status).toBe("current");
  });

  it("deduplicates self-references in related", () => {
    const term = computed(() => makeTerm({
      related: [
        { ref: { source: "urn:oiml:pub:v:2:1993", id: "5.24", edition_label: "VIM 1993" } },
      ],
    }));
    const { conceptVersions } = useConceptVersions(term, computed(() => 1));
    expect(conceptVersions.value).toHaveLength(1);
  });

  it("promotes cross-vocabulary related concepts to version cards", () => {
    const term = computed(() => makeTerm({
      related: [
        { ref: { source: "urn:oiml:pub:v:1:2022", id: "0.06", edition_label: "VIML 2022", role: "current", definition_text: "VIML def" } },
      ],
    }));
    const { conceptVersions } = useConceptVersions(term, computed(() => 1));
    expect(conceptVersions.value).toHaveLength(2);
    expect(conceptVersions.value[1].crossVocab).toBe(true);
    expect(conceptVersions.value[1].status).toBe("current");
  });

  it("filters same-vocabulary cross-references into seeAlso", () => {
    const term = computed(() => makeTerm({
      related: [
        { ref: { source: "urn:oiml:pub:v:2:1993", id: "5.27", edition_label: "VIM 1993", definition_text: "repeatability" } },
        { ref: { source: "urn:oiml:pub:v:1:2022", id: "0.06", edition_label: "VIML 2022", role: "current", definition_text: "VIML def" } },
      ],
    }));
    const { seeAlso, conceptVersions } = useConceptVersions(term, computed(() => 1));
    expect(seeAlso.value).toHaveLength(1);
    expect(seeAlso.value[0].ref.id).toBe("5.27");
    expect(conceptVersions.value).toHaveLength(2);
  });

  it("synthesizes conceptActions from suggested_actions", () => {
    const term = computed(() => makeTerm({
      related: [
        { ref: { source: "urn:oiml:pub:v:1:2022", id: "0.06", edition_label: "VIML 2022", role: "current", definition_text: "VIML def" } },
      ],
      suggested_actions: [
        { type: "removed", priority: "high", description: "Update the citation", publication_ids: [] },
        { type: "harmonize", priority: "high", description: "3 distinct defs", publication_ids: [] },
        { type: "unique", priority: "info", description: "V 3 candidate?", publication_ids: [] },
      ],
    }));
    const { conceptActions } = useConceptVersions(term, computed(() => 3));
    expect(conceptActions.value).toHaveLength(3);
    expect(conceptActions.value[0].title).toContain("Cite VIML 2022");
    expect(conceptActions.value[1].title).toContain("Harmonise 3");
    expect(conceptActions.value[2].title).toContain("V 1/V 2/V 3");
  });

  it("canPropose is true for oiml_original terms", () => {
    const term = computed(() => makeTerm({ kind: "oiml_original", official_concept: null }));
    const { canPropose } = useConceptVersions(term, computed(() => 1));
    expect(canPropose.value).toBe(true);
  });

  it("canPropose is false for defined_in_vim terms", () => {
    const term = computed(() => makeTerm());
    const { canPropose } = useConceptVersions(term, computed(() => 1));
    expect(canPropose.value).toBe(false);
  });
});
