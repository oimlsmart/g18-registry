import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import DefText from "@/components/DefText.vue";

describe("DefText", () => {
  it("renders plain text unchanged", () => {
    const wrapper = mount(DefText, { props: { text: "hello world" } });
    expect(wrapper.text()).toBe("hello world");
  });

  it("renders pre-rendered MathML via v-html", () => {
    const mathml = '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi></math>';
    const wrapper = mount(DefText, { props: { text: `value ${mathml} is` } });
    expect(wrapper.html()).toContain("<math");
    expect(wrapper.html()).toContain("<mi>x</mi>");
  });

  it("converts VIM cross-references {{id,text}} into clickable links", () => {
    const wrapper = mount(DefText, {
      props: { text: "see {{3.1,measuring instrument}} for details" },
      global: { provide: { base: "/g18-registry/" } },
    });
    const html = wrapper.html();
    expect(html).toContain("href");
    expect(html).toContain("measuring-instrument");
    expect(html).toContain("measuring instrument");
    expect(html).toContain("xref");
  });

  it("handles multiple cross-references in one string", () => {
    const wrapper = mount(DefText, {
      props: { text: "{{3.1,A}} and {{3.2,B}}" },
    });
    const links = wrapper.findAll("a.xref");
    expect(links).toHaveLength(2);
  });

  it("handles empty text gracefully", () => {
    const wrapper = mount(DefText, { props: { text: "" } });
    expect(wrapper.text()).toBe("");
  });

  it("handles null/undefined text gracefully", () => {
    const wrapper = mount(DefText, { props: { text: undefined as any } });
    expect(wrapper.exists()).toBe(true);
  });

  it("preserves text outside of math/cross-ref markup", () => {
    const wrapper = mount(DefText, {
      props: { text: "before {{3.1,link}} after" },
    });
    const html = wrapper.html();
    expect(html).toContain("before");
    expect(html).toContain("after");
  });
});
