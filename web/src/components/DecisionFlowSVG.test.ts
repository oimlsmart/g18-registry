import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import DecisionFlowSVG from "@/components/DecisionFlowSVG.vue";

describe("DecisionFlowSVG", () => {
  it("always starts with the entry step 'Term in OIML pubs'", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "oiml_original", isCurrent: false, isSuperseded: false,
        latestCheckFound: null, hasNearMiss: false, hasWithdrawn: false,
      },
    });
    const steps = wrapper.findAll(".flow-step");
    expect(steps[0].text()).toBe("Term in OIML pubs");
    expect(steps[0].classes()).toContain("flow-entry");
  });

  it("short-circuits to 'Retire from G 18' when hasWithdrawn is true", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "defined_in_vim", isCurrent: true, isSuperseded: false,
        latestCheckFound: true, hasNearMiss: false, hasWithdrawn: true,
      },
    });
    const labels = wrapper.findAll(".flow-step").map(s => s.text());
    expect(labels).toContain("In withdrawn pub?");
    expect(labels[labels.length - 1]).toBe("Retire from G 18");
  });

  it("VIM-term current citation ends with 'Nothing to do'", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "defined_in_vim", isCurrent: true, isSuperseded: false,
        latestCheckFound: true, hasNearMiss: false, hasWithdrawn: false,
      },
    });
    const labels = wrapper.findAll(".flow-step").map(s => s.text());
    expect(labels).toContain("Citation current");
    expect(labels[labels.length - 1]).toBe("Nothing to do");
  });

  it("VIM-term outdated-but-still-present ends with 'Update resolves it'", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "defined_in_vim", isCurrent: false, isSuperseded: true,
        latestCheckFound: true, hasNearMiss: false, hasWithdrawn: false,
      },
    });
    const labels = wrapper.findAll(".flow-step").map(s => s.text());
    expect(labels).toContain("Outdated citation");
    expect(labels).toContain("Still in latest");
    expect(labels[labels.length - 1]).toBe("Update resolves it");
  });

  it("VIM-term removed from latest ends with 'Propose V 1/V 2/V 3'", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "defined_in_viml", isCurrent: false, isSuperseded: true,
        latestCheckFound: false, hasNearMiss: false, hasWithdrawn: false,
      },
    });
    const labels = wrapper.findAll(".flow-step").map(s => s.text());
    expect(labels).toContain("Removed from latest");
    expect(labels[labels.length - 1]).toBe("Propose V 1/V 2/V 3");
  });

  it("OIML-original with near-miss ends with 'Adopt V 1/V 2 or propose V 3'", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "oiml_original", isCurrent: false, isSuperseded: false,
        latestCheckFound: null, hasNearMiss: true, hasWithdrawn: false,
      },
    });
    const labels = wrapper.findAll(".flow-step").map(s => s.text());
    expect(labels).toContain("Near-miss found");
    expect(labels[labels.length - 1]).toBe("Adopt V 1/V 2 or propose V 3");
  });

  it("OIML-original without near-miss ends with 'Propose for V 3'", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "undefined", isCurrent: false, isSuperseded: false,
        latestCheckFound: null, hasNearMiss: false, hasWithdrawn: false,
      },
    });
    const labels = wrapper.findAll(".flow-step").map(s => s.text());
    expect(labels).toContain("No near-miss");
    expect(labels[labels.length - 1]).toBe("Propose for V 3");
  });

  it("renders arrows between steps", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "oiml_original", isCurrent: false, isSuperseded: false,
        latestCheckFound: null, hasNearMiss: false, hasWithdrawn: false,
      },
    });
    const arrows = wrapper.findAll(".flow-arrow");
    const steps = wrapper.findAll(".flow-step");
    expect(arrows.length).toBe(steps.length - 1);
  });

  it("applies CSS classes per step type", () => {
    const wrapper = mount(DecisionFlowSVG, {
      props: {
        kind: "defined_in_vim", isCurrent: false, isSuperseded: true,
        latestCheckFound: false, hasNearMiss: false, hasWithdrawn: false,
      },
    });
    const steps = wrapper.findAll(".flow-step");
    expect(steps[0].classes()).toContain("flow-entry");
    // Second step is a decision
    expect(steps[1].classes()).toContain("flow-decision");
    // Last step is an action
    expect(steps[steps.length - 1].classes()).toContain("flow-action");
  });
});
