# frozen_string_literal: true

require "yaml"
require "tempfile"
require_relative "../../lib/g18/migration/normalize"

RSpec.describe G18::Migration::Normalize do
  describe ".normalize_designation" do
    it "strips editorial paren citations with VIM/VIML refs" do
      r = described_class.normalize_designation("error of measurement (VIM 2012)")
      expect(r).to eq("error of measurement")
    end

    it "strips editorial bracket citations" do
      r = described_class.normalize_designation("accuracy [VIM:2007, 4.11]")
      expect(r).to eq("accuracy")
    end

    it "converts smart quotes to ASCII" do
      r = described_class.normalize_designation(%(“Hello” ‘world’))
      expect(r).to eq(%("Hello" 'world'))
    end

    it "converts dash variants to ASCII hyphen" do
      r = described_class.normalize_designation("non—linear")
      expect(r).to eq("non-linear")
    end

    it "strips trailing empty parens" do
      r = described_class.normalize_designation("mean area error ()")
      expect(r).to eq("mean area error")
    end

    it "collapses multiple whitespace" do
      r = described_class.normalize_designation("error    of   measurement")
      expect(r).to eq("error of measurement")
    end

    it "returns empty string for nil" do
      expect(described_class.normalize_designation(nil)).to eq("")
    end

    it "leaves canonical designation alone" do
      r = described_class.normalize_designation("maximum permissible error")
      expect(r).to eq("maximum permissible error")
    end
  end

  describe ".load_term_aliases" do
    it "returns empty hash when file does not exist" do
      expect(described_class.load_term_aliases("/tmp/does-not-exist.yaml")).to eq({})
    end

    it "returns empty hash when path is nil" do
      expect(described_class.load_term_aliases(nil)).to eq({})
    end

    it "builds case-insensitive alias map" do
      tmp = Tempfile.new(["aliases", ".yaml"])
      tmp.write({ "Maximum Permissible Error" => ["maximum error", "MPE"] }.to_yaml)
      tmp.close
      map = described_class.load_term_aliases(tmp.path)
      expect(map["maximum permissible error"]).to eq("Maximum Permissible Error")
      expect(map["maximum error"]).to eq("Maximum Permissible Error")
      expect(map["mpe"]).to eq("Maximum Permissible Error")
    ensure
      tmp&.unlink
    end
  end
end
