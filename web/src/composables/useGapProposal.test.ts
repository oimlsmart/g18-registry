import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  composeIssueBody,
  composeIssueUrl,
  composeIssueTitle,
  targetLabel,
  TARGET_CATEGORIES,
  categoryForTarget,
  type ProposalTarget,
  type ProposalDraft,
} from "@/composables/useGapProposal";
import type { VocabGap } from "@/composables/useVocabGaps";

const mockGap: VocabGap = {
  slug: "test-term",
  name: "test term",
  identifier: "00100",
  definitions: ["a test definition"],
  publications: [
    { publication_id: "OIML R 76-1:2006", tc_sc: "TC9/SC1", edition: "202X" },
    { publication_id: "OIML R 50-1:2014", tc_sc: "TC9/SC2", edition: "2010" },
  ],
  editions_present: ["202X", "2010"],
  near_misses: {
    vim: { found: true, match_type: "exact", designation: "test term", concept_id: "4.1", definition: "vim def", latest_label: "VIM 2012", url: "https://example.com/4.1" },
    viml: null,
  },
};

describe("useGapProposal", () => {
  describe("targetLabel", () => {
    it("returns correct labels for each target", () => {
      expect(targetLabel("V1")).toBe("VIML (V 1)");
      expect(targetLabel("V2")).toBe("VIM (V 2)");
      expect(targetLabel("V3")).toBe("V 3 (specific terms, draft)");
    });
  });

  describe("TARGET_CATEGORIES", () => {
    it("has 3 categories", () => {
      expect(TARGET_CATEGORIES).toHaveLength(3);
    });
    it("has codes V1, V2, V3", () => {
      const codes = TARGET_CATEGORIES.map(c => c.code);
      expect(codes).toContain("V1");
      expect(codes).toContain("V2");
      expect(codes).toContain("V3");
    });
    it("has concept labels (not just codes)", () => {
      const concepts = TARGET_CATEGORIES.map(c => c.concept);
      expect(concepts.some(c => c.includes("metrology"))).toBe(true);
      expect(concepts.some(c => c.includes("Specific"))).toBe(true);
    });
    it("has examples for each category", () => {
      for (const cat of TARGET_CATEGORIES) {
        expect(cat.examples).toBeTruthy();
        expect(cat.examples.length).toBeGreaterThan(5);
      }
    });
  });

  describe("categoryForTarget", () => {
    it("returns category for V1", () => {
      const cat = categoryForTarget("V1");
      expect(cat.code).toBe("V1");
      expect(cat.concept).toContain("legal metrology");
    });
    it("returns category for V3", () => {
      const cat = categoryForTarget("V3");
      expect(cat.code).toBe("V3");
      expect(cat.concept).toContain("Specific");
    });
  });

  describe("composeIssueTitle", () => {
    it("includes term name and target vocabulary", () => {
      const draft: ProposalDraft = { gap: mockGap, target: "V3", rationale: "" };
      const title = composeIssueTitle(draft);
      expect(title).toContain("test term");
      expect(title).toContain("V 3");
    });
  });

  describe("composeIssueBody", () => {
    it("includes YAML front-matter with checksum", async () => {
      const draft: ProposalDraft = { gap: mockGap, target: "V3", rationale: "Because reasons" };
      const body = await composeIssueBody(draft);
      expect(body).toContain("---");
      expect(body).toContain("kind: 'vocabulary_gap_proposal'");
      expect(body).toContain("g18_term:");
      expect(body).toContain("checksum:");
      expect(body).toContain("Because reasons");
    });

    it("includes near-miss data in YAML", async () => {
      const draft: ProposalDraft = { gap: mockGap, target: "V2", rationale: "test" };
      const body = await composeIssueBody(draft);
      expect(body).toContain("near_misses:");
      expect(body).toContain("test term");
      expect(body).toContain("4.1");
    });

    it("includes publication list", async () => {
      const draft: ProposalDraft = { gap: mockGap, target: "V3", rationale: "test" };
      const body = await composeIssueBody(draft);
      expect(body).toContain("OIML R 76-1:2006");
      expect(body).toContain("OIML R 50-1:2014");
    });
  });

  describe("composeIssueUrl", () => {
    it("builds a GitHub issues URL with encoded title and body", async () => {
      const draft: ProposalDraft = { gap: mockGap, target: "V3", rationale: "test" };
      const body = await composeIssueBody(draft);
      const url = composeIssueUrl(draft, body);
      expect(url).toContain("github.com/oimlsmart/g18-registry/issues/new");
      expect(url).toContain("title=");
      expect(url).toContain("body=");
    });
  });
});
