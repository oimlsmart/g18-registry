import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import ConceptBody from "@/components/ConceptBody.vue";

describe("ConceptBody", () => {
  it("renders nothing when data is null", () => {
    const wrapper = mount(ConceptBody, { props: { data: null } });
    expect(wrapper.find(".concept-body").exists()).toBe(false);
  });

  it("renders preferred designation as display term", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          designations: [
            { type: "expression", status: "preferred", text: "calibration" },
          ],
        },
      },
    });
    expect(wrapper.find(".concept-term").text()).toContain("calibration");
  });

  it("renders admitted expressions as synonyms", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          designations: [
            { type: "expression", status: "preferred", text: "rated operating conditions" },
            { type: "expression", status: "admitted", text: "secondary standard" },
          ],
        },
      },
    });
    expect(wrapper.find(".concept-term").text()).toContain("rated operating conditions");
    expect(wrapper.find(".concept-synonyms").text()).toContain("secondary standard");
    expect(wrapper.find(".concept-syn-label").text()).toBe("Also");
  });

  it("renders abbreviations as pills", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          designations: [
            { type: "expression", status: "preferred", text: "test" },
            { type: "abbreviation", status: "preferred", text: "ROC" },
          ],
        },
      },
    });
    expect(wrapper.find(".concept-abbrev").text()).toBe("ROC");
  });

  it("renders definitions section", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          definitions: ["operation establishing the relation between indication and quantity"],
        },
      },
    });
    expect(wrapper.findAll(".concept-defn-body")).toHaveLength(1);
    expect(wrapper.text()).toContain("establishing the relation");
  });

  it("renders notes as numbered list", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          notes: ["Note one", "Note two"],
        },
      },
    });
    expect(wrapper.findAll(".concept-numbered-list li")).toHaveLength(2);
  });

  it("renders examples as numbered list", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          examples: ["Example A", "Example B"],
        },
      },
    });
    expect(wrapper.findAll(".concept-numbered-list li")).toHaveLength(2);
  });

  it("only renders sections that have data", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          definitions: ["only defs"],
        },
      },
    });
    expect(wrapper.find(".concept-defn").exists()).toBe(true);
    expect(wrapper.find(".concept-section").exists()).toBe(false);
    expect(wrapper.find(".concept-synonyms").exists()).toBe(false);
  });

  it("renders all sections when all present", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          designations: [{ type: "expression", status: "preferred", text: "test" }],
          definitions: ["def"],
          notes: ["note"],
          examples: ["example"],
        },
      },
    });
    expect(wrapper.find(".concept-term").exists()).toBe(true);
    expect(wrapper.find(".concept-defn").exists()).toBe(true);
    expect(wrapper.findAll(".concept-section")).toHaveLength(2);
  });

  it("renders empty object gracefully", () => {
    const wrapper = mount(ConceptBody, { props: { data: {} } });
    expect(wrapper.find(".concept-body").exists()).toBe(true);
    expect(wrapper.find(".concept-term").exists()).toBe(false);
  });
});
