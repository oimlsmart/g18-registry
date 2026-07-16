# frozen_string_literal: true

require_relative "../lib/g18/fuzzy_match"

RSpec.describe G18::FuzzyMatch do
  let(:idx) do
    {
      "calibration" => { id: "2.39", definition: "set of operations..." },
      "measurement" => { id: "2.9", definition: "process..." },
      "verification" => { id: "2.44", definition: "procedure..." },
    }
  end

  describe ".tokenize" do
    it "splits on whitespace and strips non-alphanumeric" do
      tokens = described_class.tokenize("error of measurement!")
      expect(tokens).to include("error", "measurement")
    end

    it "rejects single-character tokens" do
      tokens = described_class.tokenize("a measurement of x")
      expect(tokens).to include("measurement")
      expect(tokens).not_to include("a", "x")
    end

    it "returns empty array for nil input" do
      expect(described_class.tokenize(nil)).to eq([])
    end
  end

  describe ".jaccard" do
    it "returns 1.0 for identical sets" do
      expect(described_class.jaccard(%w[a b c], %w[a b c])).to eq(1.0)
    end

    it "returns 0.0 for disjoint sets" do
      expect(described_class.jaccard(%w[a b], %w[c d])).to eq(0.0)
    end

    it "returns partial overlap" do
      result = described_class.jaccard(%w[a b c], %w[b c d])
      expect(result).to be_within(0.01).of(0.5)
    end
  end

  describe ".match" do
    it "returns exact match with similarity 1.0" do
      result = described_class.match("calibration", idx)
      expect(result[:designation]).to eq("calibration")
      expect(result[:similarity]).to eq(1.0)
    end

    it "returns fuzzy match for similar multi-word terms" do
      result = described_class.match("calibration procedure", idx)
      expect(result).not_to be_nil
      expect(result[:designation]).to eq("calibration")
    end

    it "returns nil for no match below threshold" do
      result = described_class.match("xyzabc", idx)
      expect(result).to be_nil
    end

    it "returns nil for empty index" do
      result = described_class.match("calibration", {})
      expect(result).to be_nil
    end
  end
end
