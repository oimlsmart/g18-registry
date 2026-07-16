# frozen_string_literal: true

require_relative "../../lib/g18/export"

RSpec.describe G18::Export::Deduplicator do
  let(:pubs) do
    [
      { "publication_id" => "OIML R 1", "clause" => "3.1", "definition" => "def one" },
      { "publication_id" => "OIML R 1", "clause" => "3.1", "definition" => "def one" },
      { "publication_id" => "OIML R 2", "clause" => "3.1", "definition" => "def two" },
      { "publication_id" => "OIML R 1", "clause" => "3.2", "definition" => "def three" },
      { "publication_id" => "OIML R 1", "clause" => "3.1", "definition" => "" },
    ]
  end

  describe ".by_pub_and_clause" do
    it "collapses identical (publication_id, clause) pairs to one" do
      deduped = described_class.by_pub_and_clause(pubs)
      expect(deduped.size).to eq(3)
    end

    it "preserves first occurrence" do
      deduped = described_class.by_pub_and_clause(pubs)
      expect(deduped.find { |p| p["publication_id"] == "OIML R 1" && p["clause"] == "3.1" }["definition"])
        .to eq("def one")
    end

    it "returns empty array for empty input" do
      expect(described_class.by_pub_and_clause([])).to eq([])
    end
  end

  describe ".distinct_definitions" do
    it "strips {{xref}} markup and whitespace" do
      pubs_with_markup = [
        { "definition" => "{{VIM,2.9}} error" },
        { "definition" => "  error  " },
      ]
      defs = described_class.distinct_definitions(pubs_with_markup)
      expect(defs.size).to eq(1)
      expect(defs.first).to eq("error")
    end

    it "rejects empty definitions" do
      pubs = [{ "definition" => "" }, { "definition" => nil }, { "definition" => "real" }]
      expect(described_class.distinct_definitions(pubs)).to eq(["real"])
    end
  end
end
