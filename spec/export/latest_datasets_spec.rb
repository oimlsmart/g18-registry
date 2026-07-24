# frozen_string_literal: true

require_relative "../../lib/g18"

RSpec.describe G18::Export::LatestDatasets do
  it "exposes VIM and VIML as symbol keys" do
    expect(described_class.to_h.keys).to contain_exactly(:vim, :viml)
  end

  it "returns VIM 2012 as the latest VIM edition" do
    expect(described_class[:vim][:label]).to eq("VIM 2012")
    expect(described_class[:vim][:urn]).to eq("urn:oiml:pub:v:2:2012")
  end

  it "returns VIML 2022 as the latest VIML edition" do
    expect(described_class[:viml][:label]).to eq("VIML 2022")
    expect(described_class[:viml][:urn]).to eq("urn:oiml:pub:v:1:2022")
  end

  it "iterates via #each" do
    vocabss = []
    described_class.each { |v, _| vocabss << v }
    expect(vocabss).to contain_exactly(:vim, :viml)
  end
end
