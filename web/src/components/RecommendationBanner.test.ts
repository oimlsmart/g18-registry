import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import RecommendationBanner from "@/components/RecommendationBanner.vue";

describe("RecommendationBanner", () => {
  it("renders the recommendation text and label", () => {
    const wrapper = mount(RecommendationBanner, {
      props: {
        recommendation: {
          level: "ok",
          icon: "✅",
          text: "Citation is up to date.",
          link: null,
          action: "",
        },
      },
    });
    expect(wrapper.text()).toContain("Recommendation");
    expect(wrapper.text()).toContain("Citation is up to date.");
    expect(wrapper.text()).toContain("✅");
  });

  it("applies the level CSS class", () => {
    const wrapper = mount(RecommendationBanner, {
      props: {
        recommendation: { level: "warn", icon: "⚠️", text: "outdated", link: null, action: "" },
      },
    });
    expect(wrapper.find(".recommendations-banner").classes()).toContain("rec-warn");
  });

  it("renders the action link when provided", () => {
    const wrapper = mount(RecommendationBanner, {
      props: {
        recommendation: {
          level: "info",
          icon: "📋",
          text: "propose",
          link: "/proposals/?term=x",
          action: "Propose",
        },
      },
    });
    const link = wrapper.find("a.rec-action");
    expect(link.exists()).toBe(true);
    expect(link.attributes("href")).toBe("/proposals/?term=x");
    expect(link.text()).toContain("Propose →");
  });

  it("hides the action link when null", () => {
    const wrapper = mount(RecommendationBanner, {
      props: {
        recommendation: { level: "ok", icon: "✅", text: "fine", link: null, action: "" },
      },
    });
    expect(wrapper.find("a.rec-action").exists()).toBe(false);
  });

  it("supports all four levels (ok, warn, info, none)", () => {
    for (const level of ["ok", "warn", "info", "none"]) {
      const wrapper = mount(RecommendationBanner, {
        props: {
          recommendation: { level, icon: "•", text: "t", link: null, action: "" },
        },
      });
      expect(wrapper.find(".recommendations-banner").classes()).toContain(`rec-${level}`);
    }
  });
});
