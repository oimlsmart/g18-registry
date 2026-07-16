# frozen_string_literal: true

require_relative "../lib/g18/vocabulary"

RSpec.describe G18::Vocabulary do
  describe ".vocab" do
    it "returns :vim for VIM URNs" do
      expect(described_class.vocab("urn:oiml:pub:v:2:2012")).to eq(:vim)
      expect(described_class.vocab("urn:oiml:pub:v:2:2007")).to eq(:vim)
    end

    it "returns :viml for VIML URNs" do
      expect(described_class.vocab("urn:oiml:pub:v:1:2022")).to eq(:viml)
      expect(described_class.vocab("urn:oiml:pub:v:1:2013")).to eq(:viml)
    end

    it "returns nil for unknown URNs" do
      expect(described_class.vocab("urn:oiml:pub:v:3:draft")).to be_nil
      expect(described_class.vocab(nil)).to be_nil
    end
  end

  describe ".current?" do
    it "is true for the latest VIM and VIML URNs" do
      expect(described_class.current?("urn:oiml:pub:v:2:2012")).to be(true)
      expect(described_class.current?("urn:oiml:pub:v:1:2022")).to be(true)
    end

    it "is false for prior editions" do
      expect(described_class.current?("urn:oiml:pub:v:2:2007")).to be(false)
      expect(described_class.current?("urn:oiml:pub:v:1:2013")).to be(false)
    end
  end

  describe ".superseded?" do
    it "is true for prior and legacy editions" do
      expect(described_class.superseded?("urn:oiml:pub:v:2:2007")).to be(true)
      expect(described_class.superseded?("urn:oiml:pub:v:1:2000")).to be(true)
      expect(described_class.superseded?("urn:oiml:pub:v:2:1993")).to be(true)
    end

    it "is false for current editions" do
      expect(described_class.superseded?("urn:oiml:pub:v:2:2012")).to be(false)
      expect(described_class.superseded?("urn:oiml:pub:v:1:2022")).to be(false)
    end
  end

  describe ".label" do
    it "returns 'VIM YYYY' for VIM URNs" do
      expect(described_class.label("urn:oiml:pub:v:2:2012")).to eq("VIM 2012")
    end

    it "returns 'VIML YYYY' for VIML URNs" do
      expect(described_class.label("urn:oiml:pub:v:1:2022")).to eq("VIML 2022")
    end

    it "returns nil for unknown URNs" do
      expect(described_class.label("urn:unknown")).to be_nil
    end
  end

  describe ".role" do
    it "returns :current for latest editions" do
      expect(described_class.role("urn:oiml:pub:v:2:2012")).to eq(:current)
      expect(described_class.role("urn:oiml:pub:v:1:2022")).to eq(:current)
    end

    it "returns :prior or :legacy for older editions" do
      expect(described_class.role("urn:oiml:pub:v:2:2007")).to eq(:prior)
      expect(described_class.role("urn:oiml:pub:v:2:1993")).to eq(:legacy)
    end
  end
end
