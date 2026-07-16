# frozen_string_literal: true

require_relative "../../lib/g18/export"

RSpec.describe G18::Export::Matcher do
  let(:latest_datasets) do
    {
      vim:  { urn: "urn:oiml:pub:v:2:2012",  dir: "vim-2012",  label: "VIM 2012"  },
      viml: { urn: "urn:oiml:pub:v:1:2022", dir: "viml-2022", label: "VIML 2022" },
    }
  end

  let(:idx_vim) do
    {
      "calibration" => { id: "2.39", definition: "set of operations establishing calibration" },
      "measurement" => { id: "2.9",  definition: "process of experimentally obtaining quantities" },
    }
  end

  let(:idx_viml) do
    {
      "legal metrology" => { id: "1.1", definition: "practice of metrology under legal control" },
    }
  end

  let(:latest_indices) { { vim: idx_vim, viml: idx_viml } }
  let(:latest_full)    { { vim: {}, viml: {} } }

  describe ".normalize_definition" do
    it "strips {{xref}} markup" do
      expect(described_class.normalize_definition("{{VIM,2.9}} measurement"))
        .to eq("measurement")
    end

    it "strips punctuation and lowercases" do
      expect(described_class.normalize_definition("Error, of: MEASUREMENT!"))
        .to eq("error of measurement")
    end

    it "returns empty string for nil" do
      expect(described_class.normalize_definition(nil)).to eq("")
    end
  end

  describe ".classify_alignment" do
    it "returns case 5 (none) for a term with no match" do
      r = described_class.classify_alignment("zzz-not-a-real-term", nil, latest_indices, latest_full, latest_datasets)
      expect(r["case"]).to eq(5)
      expect(r["alignment"]).to eq("none")
    end

    it "returns case 1 (aligned) when designation + definition match" do
      r = described_class.classify_alignment("calibration", "set of operations establishing calibration", latest_indices, latest_full, latest_datasets)
      expect(r["case"]).to eq(1)
      expect(r["alignment"]).to eq("aligned")
      expect(r["matched_vocab"]).to eq("vim")
    end

    it "returns case 3 (diverges) when designation matches but definition differs" do
      r = described_class.classify_alignment("calibration", "completely different definition here", latest_indices, latest_full, latest_datasets)
      expect(r["case"]).to eq(3)
      expect(r["alignment"]).to eq("diverges")
    end

    it "returns case 4 (fuzzy) when designation has a near-miss" do
      r = described_class.classify_alignment("calibration procedure", nil, latest_indices, latest_full, latest_datasets)
      expect(r["case"]).to eq(4)
      expect(r["alignment"]).to eq("fuzzy")
    end

    it "returns case 5 with nil term_name" do
      r = described_class.classify_alignment(nil, nil, latest_indices, latest_full, latest_datasets)
      expect(r["case"]).to eq(5)
    end

    it "populates matched_vocab with the lowest-case match" do
      # 'legal metrology' is in viml only — should pick viml
      r = described_class.classify_alignment("legal metrology", "practice of metrology under legal control", latest_indices, latest_full, latest_datasets)
      expect(r["case"]).to eq(1)
      expect(r["matched_vocab"]).to eq("viml")
    end
  end

  describe ".check_latest_edition" do
    it "returns nil for unknown URN" do
      r = described_class.check_latest_edition("calibration", "urn:unknown:x", nil, latest_indices, latest_datasets)
      expect(r).to be_nil
    end

    it "returns nil when term_name is nil" do
      r = described_class.check_latest_edition(nil, "urn:oiml:pub:v:2:2012", nil, latest_indices, latest_datasets)
      expect(r).to be_nil
    end

    it "returns found: true when designation exists in index" do
      r = described_class.check_latest_edition("calibration", "urn:oiml:pub:v:2:2012", "2.39", latest_indices, latest_datasets)
      expect(r["found"]).to be(true)
      expect(r["concept_id"]).to eq("2.39")
      expect(r["vocab"]).to eq("vim")
    end

    it "returns found: false when designation is not in index" do
      r = described_class.check_latest_edition("zzz-not-real", "urn:oiml:pub:v:2:2012", nil, latest_indices, latest_datasets)
      expect(r["found"]).to be(false)
    end
  end
end
