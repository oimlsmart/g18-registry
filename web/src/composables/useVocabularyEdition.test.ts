import { describe, it, expect } from "vitest";
import { useVocabularyEdition } from "@/composables/useVocabularyEdition";

const { vocab, year, role, label, confidenceClass, isCurrent, isSuperseded, latestLabel, vocabUrl } = useVocabularyEdition();

describe("useVocabularyEdition", () => {
  describe("vocab + year", () => {
    it("identifies VIM editions", () => {
      expect(vocab("urn:oiml:pub:v:2:1993")).toBe("vim");
      expect(vocab("urn:oiml:pub:v:2:2012")).toBe("vim");
    });
    it("identifies VIML editions", () => {
      expect(vocab("urn:oiml:pub:v:1:2000")).toBe("viml");
      expect(vocab("urn:oiml:pub:v:1:2022")).toBe("viml");
    });
    it("returns null for unknown URNs", () => {
      expect(vocab("urn:oiml:pub:v:3:2099")).toBeNull();
      expect(vocab("garbage")).toBeNull();
      expect(vocab("")).toBeNull();
    });
    it("extracts year from URN", () => {
      expect(year("urn:oiml:pub:v:2:1993")).toBe(1993);
      expect(year("urn:oiml:pub:v:1:2022")).toBe(2022);
      expect(year("unknown")).toBeNull();
    });
  });

  describe("role classification", () => {
    it("classifies legacy editions (VIM 1993, VIML 1968)", () => {
      expect(role("urn:oiml:pub:v:2:1993")).toBe("legacy");
      expect(role("urn:oiml:pub:v:1:1968")).toBe("legacy");
    });
    it("classifies prior editions (VIM 2007/2010, VIML 2000/2013)", () => {
      expect(role("urn:oiml:pub:v:2:2007")).toBe("prior");
      expect(role("urn:oiml:pub:v:2:2010")).toBe("prior");
      expect(role("urn:oiml:pub:v:1:2000")).toBe("prior");
      expect(role("urn:oiml:pub:v:1:2013")).toBe("prior");
    });
    it("classifies current editions (VIM 2012, VIML 2022)", () => {
      expect(role("urn:oiml:pub:v:2:2012")).toBe("current");
      expect(role("urn:oiml:pub:v:1:2022")).toBe("current");
    });
  });

  describe("label", () => {
    it("formats VIM labels", () => {
      expect(label("urn:oiml:pub:v:2:1993")).toBe("VIM 1993");
      expect(label("urn:oiml:pub:v:2:2012")).toBe("VIM 2012");
    });
    it("formats VIML labels", () => {
      expect(label("urn:oiml:pub:v:1:2022")).toBe("VIML 2022");
    });
    it("returns raw URN for unknown", () => {
      expect(label("unknown")).toBe("unknown");
    });
  });

  describe("isCurrent + isSuperseded", () => {
    it("isCurrent returns true only for current editions", () => {
      expect(isCurrent("urn:oiml:pub:v:2:2012")).toBe(true);
      expect(isCurrent("urn:oiml:pub:v:1:2022")).toBe(true);
      expect(isCurrent("urn:oiml:pub:v:2:1993")).toBe(false);
      expect(isCurrent("urn:oiml:pub:v:2:2007")).toBe(false);
    });
    it("isSuperseded returns true for legacy and prior", () => {
      expect(isSuperseded("urn:oiml:pub:v:2:1993")).toBe(true);
      expect(isSuperseded("urn:oiml:pub:v:2:2007")).toBe(true);
      expect(isSuperseded("urn:oiml:pub:v:2:2012")).toBe(false);
      expect(isSuperseded("urn:oiml:pub:v:1:2022")).toBe(false);
    });
  });

  describe("latestLabel", () => {
    it("returns VIM 2012 for VIM URNs", () => {
      expect(latestLabel("urn:oiml:pub:v:2:1993")).toBe("VIM 2012");
      expect(latestLabel("urn:oiml:pub:v:2:2007")).toBe("VIM 2012");
    });
    it("returns VIML 2022 for VIML URNs", () => {
      expect(latestLabel("urn:oiml:pub:v:1:2000")).toBe("VIML 2022");
      expect(latestLabel("urn:oiml:pub:v:1:2013")).toBe("VIML 2022");
    });
  });

  describe("vocabUrl", () => {
    it("constructs vocab site URLs", () => {
      expect(vocabUrl("urn:oiml:pub:v:2:2012", "5.4")).toBe("https://oimlsmart.github.io/vocab/vim-2012/concept/5.4");
      expect(vocabUrl("urn:oiml:pub:v:1:2022", "0.06")).toBe("https://oimlsmart.github.io/vocab/viml-2022/concept/0.06");
    });
    it("returns null for unknown URN or missing id", () => {
      expect(vocabUrl("unknown", "1")).toBeNull();
      expect(vocabUrl("urn:oiml:pub:v:2:2012", "")).toBeNull();
    });
  });

  describe("confidenceClass", () => {
    it("returns viml-ref class string for known URNs", () => {
      expect(confidenceClass("urn:oiml:pub:v:2:2012")).toBe("viml-ref vim-current");
      expect(confidenceClass("urn:oiml:pub:v:2:1993")).toBe("viml-ref vim-legacy");
      expect(confidenceClass("urn:oiml:pub:v:1:2022")).toBe("viml-ref viml-current");
    });
    it("returns empty string for unknown URNs", () => {
      expect(confidenceClass("unknown")).toBe("");
    });
  });
});
