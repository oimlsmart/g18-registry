# frozen_string_literal: true

require_relative "../../lib/g18"

RSpec.describe G18::Migration::SourceClassification do
  describe ".adoption_kind" do
    it "classifies VIM URN references" do
      expect(described_class.adoption_kind("urn:oiml:pub:v:2:2012")).to eq("vim")
    end

    it "classifies OIML V 2-200 references as VIM" do
      expect(described_class.adoption_kind("OIML V 2-200:2012")).to eq("vim")
    end

    it "classifies VIML URN references" do
      expect(described_class.adoption_kind("urn:oiml:pub:v:1:2022")).to eq("viml")
    end

    it "classifies OIML V 1 references as VIML" do
      expect(described_class.adoption_kind("OIML V 1:2022")).to eq("viml")
    end

    it "classifies OIML publication references" do
      expect(described_class.adoption_kind("OIML R 1:2020")).to eq("oiml_pub")
      expect(described_class.adoption_kind("OIML D 11:2013")).to eq("oiml_pub")
    end

    it "falls back to 'other' for unknown sources" do
      expect(described_class.adoption_kind("ISO 9001")).to eq("other")
    end
  end

  describe ".urn?" do
    it "returns true for VIM/VIML URNs" do
      expect(described_class.urn?("urn:oiml:pub:v:2:2012")).to be(true)
      expect(described_class.urn?("urn:oiml:pub:v:1:2022")).to be(true)
    end

    it "returns false for non-URN strings" do
      expect(described_class.urn?("OIML R 1:2020")).to be(false)
      expect(described_class.urn?(nil)).to be(false)
    end
  end

  describe ".vimline_source?" do
    it "returns true for VIM/VIML references" do
      expect(described_class.vimline_source?("urn:oiml:pub:v:2:2012")).to be(true)
      expect(described_class.vimline_source?("OIML V 2-200:2012")).to be(true)
      expect(described_class.vimline_source?("VIM 2012")).to be(true)
    end

    it "returns false for OIML pub references" do
      expect(described_class.vimline_source?("OIML R 1:2020")).to be(false)
    end
  end

  describe ".source_origin_source" do
    it "handles string ref (new vocab v3 shape)" do
      src = { "origin" => { "ref" => "OIML R 49-1:2003 (E)" } }
      expect(described_class.source_origin_source(src)).to eq("OIML R 49-1:2003 (E)")
    end

    it "handles hash ref (legacy shape)" do
      src = { "origin" => { "ref" => { "source" => "OIML R 49-1:2003 (E)", "id" => "3.1" } } }
      expect(described_class.source_origin_source(src)).to eq("OIML R 49-1:2003 (E)")
    end

    it "returns nil for missing ref" do
      expect(described_class.source_origin_source({})).to be_nil
    end
  end

  describe ".source_origin_id" do
    it "returns nil for string ref (new shape has no id)" do
      src = { "origin" => { "ref" => "OIML R 49-1:2003 (E)" } }
      expect(described_class.source_origin_id(src)).to be_nil
    end

    it "returns id for hash ref (legacy shape)" do
      src = { "origin" => { "ref" => { "source" => "X", "id" => "3.1" } } }
      expect(described_class.source_origin_id(src)).to eq("3.1")
    end
  end

  describe ".adoption_relationship" do
    it "returns status from hash source" do
      src = { "status" => "identical" }
      expect(described_class.adoption_relationship(src)).to eq("identical")
    end

    it "falls back to type when status absent" do
      src = { "type" => "authoritative" }
      expect(described_class.adoption_relationship(src)).to eq("authoritative")
    end

    it "defaults to authoritative when neither present" do
      expect(described_class.adoption_relationship({})).to eq("authoritative")
    end
  end

  describe ".source_modification" do
    it "extracts modification from hash source" do
      src = { "modification" => "adapted wording" }
      expect(described_class.source_modification(src)).to eq("adapted wording")
    end

    it "returns nil when no modification" do
      expect(described_class.source_modification({})).to be_nil
    end
  end

  # Verify Loaders delegates correctly
  describe "Loaders delegation" do
    it "Loaders.adoption_kind delegates to SourceClassification" do
      expect(G18::Migration::Loaders.adoption_kind("urn:oiml:pub:v:2:2012"))
        .to eq(G18::Migration::SourceClassification.adoption_kind("urn:oiml:pub:v:2:2012"))
    end
  end
end
