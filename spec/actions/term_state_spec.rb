# frozen_string_literal: true

require_relative "../../lib/g18/actions"

RSpec.describe G18::Actions::TermState do
  let(:term) do
    {
      "data" => {
        "kind" => "oiml_original",
        "term" => "calibration",
        "publications" => [
          { "publication_id" => "OIML R 1", "edition" => "202X", "definition" => "def A" },
          { "publication_id" => "OIML R 2", "edition" => "202X", "definition" => "def B" },
          { "publication_id" => "OIML R 3", "edition" => "2010", "definition" => "def A" },
        ],
        "official_concept" => { "source" => "urn:oiml:pub:v:2:2012", "id" => "2.9" },
      },
      "alignment" => { "case" => 5, "alignment" => "none" },
    }
  end

  subject(:state) { described_class.from(term) }

  it "exposes data, pubs, official_concept, kind, alignment" do
    expect(state.data["term"]).to eq("calibration")
    expect(state.pubs.size).to eq(3)
    expect(state.official_concept["id"]).to eq("2.9")
    expect(state.kind).to eq("oiml_original")
    expect(state.alignment["case"]).to eq(5)
  end

  describe "#distinct_definitions" do
    it "returns uniq non-empty normalized definitions across all editions" do
      expect(state.distinct_definitions).to eq(["def A", "def B"])
    end
  end

  describe "#distinct_definitions_per_edition" do
    it "groups by edition" do
      per_ed = state.distinct_definitions_per_edition
      expect(per_ed["202X"]).to contain_exactly("def A", "def B")
      expect(per_ed["2010"]).to eq(["def A"])
    end
  end

  describe "#has_divergence" do
    it "is true when any edition has ≥ 2 distinct definitions" do
      expect(state.has_divergence).to be(true)
    end

    it "is false when every edition has only 1 definition" do
      no_div = described_class.from("data" => {
        "publications" => [
          { "edition" => "202X", "definition" => "same" },
          { "edition" => "2010", "definition" => "different" },
        ],
      })
      expect(no_div.has_divergence).to be(false)
    end
  end

  describe "#oiml_specific?" do
    it "is true for kind=oiml_original" do
      expect(described_class.from("data" => { "kind" => "oiml_original" }).oiml_specific?).to be(true)
    end

    it "is true for kind=undefined" do
      expect(described_class.from("data" => { "kind" => "undefined" }).oiml_specific?).to be(true)
    end

    it "is false for kind=defined_in_vim" do
      expect(described_class.from("data" => { "kind" => "defined_in_vim" }).oiml_specific?).to be(false)
    end
  end

  describe "#publication_ids" do
    it "returns unique publication_ids" do
      expect(state.publication_ids).to eq(["OIML R 1", "OIML R 2", "OIML R 3"])
    end
  end

  describe "#superseded_urn?" do
    it "is true for old VIM URNs (vim vocab)" do
      expect(state.superseded_urn?("urn:oiml:pub:v:2:2007", vocab: :vim)).to be(true)
    end

    it "is false for current VIM URN" do
      expect(state.superseded_urn?("urn:oiml:pub:v:2:2012", vocab: :vim)).to be(false)
    end

    it "is true for old VIML URNs (viml vocab)" do
      expect(state.superseded_urn?("urn:oiml:pub:v:1:2013", vocab: :viml)).to be(true)
    end

    it "handles non-URN source strings like 'OIML V 2-200:2007'" do
      expect(state.superseded_urn?("OIML V 2-200:2007", vocab: :vim)).to be(true)
    end

    it "returns false for nil urn" do
      expect(state.superseded_urn?(nil, vocab: :vim)).to be(false)
    end
  end

  describe "#normalize_definition" do
    it "strips {{id,text}} cross-ref markup, keeping the designation" do
      # Real format: {{A.15,attestation}} — id first, designation second
      expect(state.normalize_definition("{{A.15,attestation}} scheme")).to eq("attestation scheme")
    end

    it "returns empty string for non-String" do
      expect(state.normalize_definition(nil)).to eq("")
      expect(state.normalize_definition(42)).to eq("")
    end
  end

  it "memoizes distinct_definitions" do
    expect(state.distinct_definitions).to be(state.distinct_definitions)
  end
end
