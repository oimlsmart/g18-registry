import { describe, it, expect } from "vitest";
import { kindLabel, isHistoricTerm, slugify, normalizeDef } from "@/utils/term-utils";

describe("term-utils", () => {
  describe("kindLabel", () => {
    it("maps known kinds to vocabulary labels", () => {
      expect(kindLabel("defined_in_vim")).toBe("VIM");
      expect(kindLabel("defined_in_viml")).toBe("VIML");
    });
    it("returns dash for unknown or oiml_original", () => {
      expect(kindLabel("oiml_original")).toBe("—");
      expect(kindLabel("undefined")).toBe("—");
      expect(kindLabel("")).toBe("—");
    });
  });

  describe("isHistoricTerm", () => {
    it("returns true for 2010-only terms", () => {
      expect(isHistoricTerm({ editions_present: ["2010"] })).toBe(true);
      expect(isHistoricTerm(["2010"])).toBe(true);
    });
    it("returns false for terms in both editions", () => {
      expect(isHistoricTerm({ editions_present: ["2010", "202X"] })).toBe(false);
      expect(isHistoricTerm(["2010", "202X"])).toBe(false);
    });
    it("returns false for 202X-only terms", () => {
      expect(isHistoricTerm({ editions_present: ["202X"] })).toBe(false);
    });
    it("returns false for empty editions", () => {
      expect(isHistoricTerm({ editions_present: [] })).toBe(false);
      expect(isHistoricTerm([])).toBe(false);
    });
  });

  describe("slugify", () => {
    it("lowercases and hyphenates", () => {
      expect(slugify("OIML R 76-1:2006")).toBe("oiml-r-76-1-2006");
      expect(slugify("TC9/SC1")).toBe("tc9-sc1");
    });
    it("handles null/undefined gracefully", () => {
      expect(slugify(null as any)).toBe("");
      expect(slugify(undefined as any)).toBe("");
    });
  });

  describe("normalizeDef", () => {
    it("strips {{id,text}} cross-reference markup", () => {
      expect(normalizeDef("see {{3.1,measuring instrument}} here")).toBe("see measuring instrument here");
    });
    it("strips multiple cross-references", () => {
      expect(normalizeDef("{{3.1,A}} and {{3.2,B}}")).toBe("A and B");
    });
    it("trims whitespace", () => {
      expect(normalizeDef("  hello  ")).toBe("hello");
    });
    it("handles empty/null gracefully", () => {
      expect(normalizeDef("")).toBe("");
    });
    it("leaves plain text unchanged (after trim)", () => {
      expect(normalizeDef("definition without refs")).toBe("definition without refs");
    });
  });
});
