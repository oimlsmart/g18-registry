import { describe, it, expect } from "vitest";
import { editionDataName, editionUiLabel, sortedEditions, isOimlSpecific } from "@/utils/edition-utils";

describe("edition-utils", () => {
  describe("editionDataName", () => {
    it("maps 'current' to 'complete'", () => {
      expect(editionDataName("current")).toBe("complete");
    });
    it("passes through other names unchanged", () => {
      expect(editionDataName("202X")).toBe("202X");
      expect(editionDataName("2010")).toBe("2010");
    });
  });

  describe("editionUiLabel", () => {
    it("maps 'complete' to 'OIML'", () => {
      expect(editionUiLabel("complete")).toBe("OIML");
    });
    it("passes through other names", () => {
      expect(editionUiLabel("202X")).toBe("202X");
    });
  });

  describe("sortedEditions", () => {
    it("sorts editions in canonical order", () => {
      const result = sortedEditions(["2010", "complete", "202X"]);
      expect(result).toEqual(["complete", "202X", "2010"]);
    });
    it("includes V1/V2 editions after G18", () => {
      const result = sortedEditions(["vim-2012", "2010", "complete"]);
      expect(result).toEqual(["complete", "2010", "vim-2012"]);
    });
    it("handles undefined", () => {
      expect(sortedEditions(undefined)).toEqual([]);
    });
  });

  describe("isOimlSpecific", () => {
    it("returns true for oiml_original", () => {
      expect(isOimlSpecific("oiml_original")).toBe(true);
    });
    it("returns true for undefined (legacy)", () => {
      expect(isOimlSpecific("undefined")).toBe(true);
    });
    it("returns false for defined_in_vim", () => {
      expect(isOimlSpecific("defined_in_vim")).toBe(false);
    });
    it("returns false for defined_in_viml", () => {
      expect(isOimlSpecific("defined_in_viml")).toBe(false);
    });
  });
});
