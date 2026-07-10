import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import ConceptBody from "@/components/ConceptBody.vue";

describe("ConceptBody", () => {
  it("renders nothing when data is null", () => {
    const wrapper = mount(ConceptBody, { props: { data: null } });
    expect(wrapper.find(".concept-body").exists()).toBe(false);
  });

  it("renders designations with status badges", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          designations: [
            { type: "expression", status: "preferred", text: "calibration" },
            { type: "abbreviation", status: "admitted", text: "cal" },
          ],
        },
      },
    });
    expect(wrapper.findAll(".full-concept-designations li")).toHaveLength(2);
    expect(wrapper.find(".kind-preferred").text()).toBe("preferred");
    expect(wrapper.find(".kind-admitted").text()).toBe("admitted");
  });

  it("renders expression designations as DefText, others as code", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          designations: [
            { type: "expression", status: "preferred", text: "measuring instrument" },
            { type: "symbol", status: "preferred", text: "M" },
          ],
        },
      },
    });
    const items = wrapper.findAll(".full-concept-designations li");
    expect(items[0].find(".def-text").exists()).toBe(true);
    expect(items[1].find("code").exists()).toBe(true);
  });

  it("renders definitions section", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          definitions: ["operation establishing the relation between the indication and the quantity"],
        },
      },
    });
    expect(wrapper.findAll(".authority-defn-body")).toHaveLength(1);
    expect(wrapper.text()).toContain("establishing the relation");
  });

  it("renders notes as ordered list", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          notes: ["Note one", "Note two"],
        },
      },
    });
    expect(wrapper.findAll(".full-concept-list li")).toHaveLength(2);
    expect(wrapper.find("ol.full-concept-list").exists()).toBe(true);
  });

  it("renders examples as ordered list", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          examples: ["Example A", "Example B"],
        },
      },
    });
    expect(wrapper.findAll(".full-concept-list li")).toHaveLength(2);
  });

  it("only renders sections that have data", () => {
    const wrapper = mount(ConceptBody, {
      props: {
        data: {
          definitions: ["only defs"],
        },
      },
    });
    expect(wrapper.findAll(".full-concept-section")).toHaveLength(1);
    expect(wrapper.text()).toContain("Definition");
    expect(wrapper.text()).not.toContain("Notes");
    expect(wrapper.text()).not.toContain("Examples");
  });

  it("renders all four sections when all present", () => {
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
    expect(wrapper.findAll(".full-concept-section")).toHaveLength(4);
  });

  it("renders empty object gracefully (no sections)", () => {
    const wrapper = mount(ConceptBody, { props: { data: {} } });
    expect(wrapper.find(".concept-body").exists()).toBe(true);
    expect(wrapper.findAll(".full-concept-section")).toHaveLength(0);
  });
});
