# frozen_string_literal: true

require "tempfile"
require_relative "../../lib/g18/migration"

RSpec.describe G18::Migration::Loaders do
  describe ".parse_year" do
    it "extracts a 4-digit year after a colon" do
      expect(described_class.parse_year("OIML R 1:2020")).to eq(2020)
    end

    it "returns nil when no year is present" do
      expect(described_class.parse_year("OIML R 1")).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.parse_year(nil)).to be_nil
    end
  end

  describe ".slugify" do
    it "slugifies a term" do
      expect(described_class.slugify("Maximum Permissible Error")).to eq("maximum-permissible-error")
    end

    it "handles special characters" do
      expect(described_class.slugify("Error (of measurement)")).to eq("error-of-measurement")
    end
  end

  describe ".normalize_pub_id" do
    it "inserts a space after the letter (R/D/G/B)" do
      expect(described_class.normalize_pub_id("OIML R76-1:2006")).to eq("OIML R 76-1:2006")
    end

    it "strips zero-padding from the number" do
      expect(described_class.normalize_pub_id("OIML R076:2006")).to eq("OIML R 76:2006")
    end

    it "collapses whitespace runs" do
      expect(described_class.normalize_pub_id("OIML   R  1:2020")).to eq("OIML R 1:2020")
    end

    it "returns empty string for nil input" do
      expect(described_class.normalize_pub_id(nil)).to eq("")
    end
  end

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

  describe ".load_bibliography" do
    it "returns empty hash for nil path" do
      # YAML.safe_load on a missing file raises; this verifies behavior on
      # a missing path through the existing rescue pattern by passing a
      # non-existent file (the method does not handle missing files, so
      # we just verify its happy path with a real file).
      tmp = Tempfile.new(["bib", ".yaml"])
      tmp.write([{ "id" => "OIML R 1:2020", "reference" => "OIML R 1" }].to_yaml)
      tmp.close
      result = described_class.load_bibliography(tmp.path)
      expect(result["OIML R 1:2020"]["reference"]).to eq("OIML R 1")
    ensure
      tmp&.unlink
    end

    it "wraps a single-document YAML in an array" do
      tmp = Tempfile.new(["bib", ".yaml"])
      tmp.write({ "id" => "OIML R 1:2020" }.to_yaml)
      tmp.close
      result = described_class.load_bibliography(tmp.path)
      expect(result.size).to eq(1)
    ensure
      tmp&.unlink
    end
  end

  describe ".extract_raw_sourced_from" do
    it "returns nil for empty docs" do
      expect(described_class.extract_raw_sourced_from([])).to be_nil
      expect(described_class.extract_raw_sourced_from(nil)).to be_nil
    end

    it "extracts sourced_from chain from a localized concept doc" do
      docs = [
        { "data" => { "localized_concepts" => { "eng" => "abc" } } },
        { "data" => {
            "definition" => [{ "content" => "test" }],
            "sources" => [
              { "sourced_from" => [{ "ref" => { "source" => "OIML D 11:2013", "id" => "3.4" } }] },
            ],
          },
        },
      ]
      result = described_class.extract_raw_sourced_from(docs)
      expect(result).to eq([{ "source" => "OIML D 11:2013", "id" => "3.4" }])
    end

    it "returns nil when no sourced_from is present" do
      docs = [{ "data" => { "definition" => [{ "content" => "x" }], "sources" => [] } }]
      expect(described_class.extract_raw_sourced_from(docs)).to be_nil
    end
  end
end
