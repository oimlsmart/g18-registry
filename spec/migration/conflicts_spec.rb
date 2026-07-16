# frozen_string_literal: true

require_relative "../../lib/g18/migration/conflicts"

RSpec.describe G18::Migration::Conflicts do
  describe ".base_identifier" do
    it "strips 2010 a/b suffix" do
      expect(described_class.base_identifier("00474a")).to eq("00474")
      expect(described_class.base_identifier("00474b")).to eq("00474")
    end

    it "strips 202X -RXXX-N publication suffix" do
      expect(described_class.base_identifier("02344-R049-1")).to eq("02344")
      expect(described_class.base_identifier("02344-R099-1")).to eq("02344")
    end

    it "strips -RXXX (without trailing -N) suffix" do
      expect(described_class.base_identifier("02344-R108")).to eq("02344")
    end

    it "leaves canonical IDs unchanged" do
      expect(described_class.base_identifier("00474")).to eq("00474")
      expect(described_class.base_identifier("02344")).to eq("02344")
    end

    it "handles nil and non-string inputs gracefully" do
      expect(described_class.base_identifier(nil)).to eq("")
      expect(described_class.base_identifier(42)).to eq("42")
    end
  end
end
