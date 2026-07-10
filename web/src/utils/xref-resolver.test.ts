import { describe, it, expect } from "vitest";
import { resolveXrefSlug, singularize, slugifyText } from "@/utils/xref-resolver";

describe("singularize", () => {
  it("converts ies → y", () => {
    expect(singularize("uncertainties")).toBe("uncertainty");
    expect(singularize("categories")).toBe("category");
  });
  it("strips trailing s", () => {
    expect(singularize("instruments")).toBe("instrument");
    expect(singularize("systems")).toBe("system");
  });
  it("leaves singular unchanged", () => {
    expect(singularize("instrument")).toBe("instrument");
    expect(singularize("accuracy")).toBe("accuracy");
  });
});

describe("slugifyText", () => {
  it("lowercases and hyphenates", () => {
    expect(slugifyText("Measuring Instrument")).toBe("measuring-instrument");
  });
  it("strips non-alphanumeric", () => {
    expect(slugifyText("error (of a measurement)")).toBe("error-of-a-measurement");
  });
});

describe("resolveXrefSlug", () => {
  it("resolves by concept ID when G 18 term cites same edition", () => {
    // accuracy-class has official_concept.id = "5.19" in VIM 1993
    expect(resolveXrefSlug("5.19", "accuracy class")).toBe("accuracy-class");
  });

  it("resolves by exact name match when concept ID differs across editions", () => {
    // VIM 2012 #3.1 = "measuring instruments" but G 18 term is "measuring instrument" (VIM 1993 #4.1)
    expect(resolveXrefSlug("3.1", "measuring instrument")).toBe("measuring-instrument");
  });

  it("resolves by singularized name match for plural xref text", () => {
    expect(resolveXrefSlug("3.1", "measuring instruments")).toBe("measuring-instrument");
    expect(resolveXrefSlug("3.2", "measuring systems")).toBe("measuring-system");
  });

  it("resolves by slugified text when slug exists in G 18", () => {
    expect(resolveXrefSlug("99", "accuracy class")).toBe("accuracy-class");
  });

  it("returns null for terms not in G 18", () => {
    expect(resolveXrefSlug("99", "nonexistent term")).toBeNull();
  });

  it("returns null for empty text", () => {
    expect(resolveXrefSlug("1", "")).toBeNull();
  });
});
