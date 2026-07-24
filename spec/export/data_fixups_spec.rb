# frozen_string_literal: true

require_relative "../../lib/g18"

RSpec.describe G18::Export::DataFixups do
  describe ".apply_to_publication!" do
    it "fixes R 142-1:2025 ref_source" do
      pub = { "publication_id" => "OIML R 142-1:2025", "source" => { "ref_source" => "OIML V 2-200:2007" } }
      described_class.apply_to_publication!(pub)
      expect(pub["source"]["ref_source"]).to eq("OIML V 2-200:2012")
    end

    it "fixes R 99-1:2008 aquantity typo" do
      pub = { "publication_id" => "OIML R 99-1:2008", "definition" => "is aquantity of measurement" }
      described_class.apply_to_publication!(pub)
      expect(pub["definition"]).to eq("is a quantity of measurement")
    end

    it "is a no-op for publications without a known fixup" do
      pub = { "publication_id" => "OIML R 999:2099", "definition" => "untouched" }
      described_class.apply_to_publication!(pub)
      expect(pub["definition"]).to eq("untouched")
    end

    it "skips ref_source fixup when source is not a Hash" do
      pub = { "publication_id" => "OIML R 142-1:2025", "source" => "string-source" }
      described_class.apply_to_publication!(pub)
      expect(pub["source"]).to eq("string-source")
    end
  end
end
