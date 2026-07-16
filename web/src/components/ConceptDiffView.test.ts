import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import ConceptDiffView from "@/components/ConceptDiffView.vue";

describe("ConceptDiffView", () => {
  it("renders nothing visible when diff is falsy", () => {
    const wrapper = mount(ConceptDiffView, { props: { diff: null } });
    expect(wrapper.find(".concept-diff").exists()).toBe(false);
  });

  it("renders the designation changes section when present", () => {
    const wrapper = mount(ConceptDiffView, {
      props: {
        diff: {
          designations: {
            removed: ["old term"],
            added: ["new term"],
            changed: [],
          },
        },
      },
    });
    expect(wrapper.text()).toContain("Designation changes");
    expect(wrapper.text()).toContain("old term");
    expect(wrapper.text()).toContain("new term");
  });

  it("renders designation field change with arrow", () => {
    const wrapper = mount(ConceptDiffView, {
      props: {
        diff: {
          designations: {
            removed: [], added: [],
            changed: [{ from: "Alpha", to: "Beta", field: "designation" }],
          },
        },
      },
    });
    expect(wrapper.text()).toContain("Alpha");
    expect(wrapper.text()).toContain("Beta");
    expect(wrapper.text()).toContain("→");
    // designation-field change should NOT show the (field) annotation
    expect(wrapper.text()).not.toContain("(designation)");
  });

  it("renders non-designation field changes with annotation", () => {
    const wrapper = mount(ConceptDiffView, {
      props: {
        diff: {
          designations: {
            removed: [], added: [],
            changed: [{ from: "x", to: "y", field: "usage_info" }],
          },
        },
      },
    });
    expect(wrapper.text()).toContain("(usage_info)");
  });

  it("renders definition changes (old + new)", () => {
    const wrapper = mount(ConceptDiffView, {
      props: {
        diff: {
          definitions: {
            changed: [{ old: "old defn", new: "new defn" }],
            added: [],
          },
        },
      },
    });
    expect(wrapper.text()).toContain("Definition changes");
    expect(wrapper.text()).toContain("old defn");
    expect(wrapper.text()).toContain("new defn");
  });

  it("renders notes +/- markers", () => {
    const wrapper = mount(ConceptDiffView, {
      props: {
        diff: {
          notes: {
            added: ["new note"],
            removed: ["old note"],
          },
        },
      },
    });
    expect(wrapper.text()).toContain("Note changes");
    expect(wrapper.text()).toContain("+ new note");
    expect(wrapper.text()).toContain("− old note");
  });

  it("renders examples +/- markers", () => {
    const wrapper = mount(ConceptDiffView, {
      props: {
        diff: {
          examples: {
            added: ["new example"],
            removed: [],
          },
        },
      },
    });
    expect(wrapper.text()).toContain("Example changes");
    expect(wrapper.text()).toContain("+ new example");
  });

  it("omits sections that are absent from the diff", () => {
    const wrapper = mount(ConceptDiffView, {
      props: { diff: { definitions: { changed: [], added: [] } } },
    });
    expect(wrapper.text()).toContain("Definition changes");
    expect(wrapper.text()).not.toContain("Designation changes");
    expect(wrapper.text()).not.toContain("Note changes");
  });

  it("renders all four sections together", () => {
    const wrapper = mount(ConceptDiffView, {
      props: {
        diff: {
          designations: { removed: [], added: [], changed: [] },
          definitions: { changed: [], added: [] },
          notes: { added: [], removed: [] },
          examples: { added: [], removed: [] },
        },
      },
    });
    expect(wrapper.text()).toContain("Designation changes");
    expect(wrapper.text()).toContain("Definition changes");
    expect(wrapper.text()).toContain("Note changes");
    expect(wrapper.text()).toContain("Example changes");
  });
});
