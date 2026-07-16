# frozen_string_literal: true

require_relative "../../lib/g18/migration"

RSpec.describe G18::Model::PubId do
  describe ".parse_year" do
    it "extracts the 4-digit year suffix" do
      expect(described_class.parse_year("OIML R 1:2020")).to eq(2020)
      expect(described_class.parse_year("OIML D 11:2004")).to eq(2004)
    end

    it "returns nil when no :YYYY suffix is present" do
      expect(described_class.parse_year("OIML R 1")).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.parse_year(nil)).to be_nil
    end

    it "returns nil for non-string input" do
      expect(described_class.parse_year(42)).to be_nil
    end

    it "does not match years not preceded by a colon" do
      expect(described_class.parse_year("R 1 (2020)")).to be_nil
    end
  end

  describe ".normalize" do
    it "inserts a space after the letter and strips zero-padding" do
      expect(described_class.normalize("OIML R076-1:2006")).to eq("OIML R 76-1:2006")
      expect(described_class.normalize("OIML D011:2004")).to eq("OIML D 11:2004")
    end

    it "preserves already-canonical form" do
      expect(described_class.normalize("OIML R 76-1:2006")).to eq("OIML R 76-1:2006")
    end

    it "collapses whitespace runs" do
      expect(described_class.normalize("OIML   R  1:2020")).to eq("OIML R 1:2020")
    end

    it "handles OIML B-series" do
      expect(described_class.normalize("OIML B 10-1:2004")).to eq("OIML B 10-1:2004")
    end

    it "returns empty string for nil" do
      expect(described_class.normalize(nil)).to eq("")
    end

    it "uppercases OIML prefix but preserves letter case (matches frontend)" do
      # Regex /i makes the match case-insensitive; replacement preserves $1 case
      expect(described_class.normalize("oiml r 1:2020")).to eq("OIML r 1:2020")
    end
  end
end

# Verify Loaders delegates correctly (backward compat)
RSpec.describe G18::Migration::Loaders, "#parse_year and #normalize_pub_id delegation" do
  it "parse_year delegates to Model::PubId.parse_year" do
    expect(described_class.parse_year("OIML R 1:2020")).to eq(G18::Model::PubId.parse_year("OIML R 1:2020"))
  end

  it "normalize_pub_id delegates to Model::PubId.normalize" do
    expect(described_class.normalize_pub_id("OIML R076:2006")).to eq(G18::Model::PubId.normalize("OIML R076:2006"))
  end
end
