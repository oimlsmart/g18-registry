# frozen_string_literal: true

require "set"
require_relative "../../lib/g18"

RSpec.describe G18::Migration::Builders do
  # The Builders module delegates heavily to Loaders. These specs focus on
  # pure helpers that don't require a real glossarist instance.

  describe ".pick_official" do
    it "returns oiml_original with nil official when edges are empty" do
      kind, official = described_class.pick_official([])
      expect(kind).to eq("oiml_original")
      expect(official).to be_nil
    end

    it "returns kind + official ref from first edge" do
      edges = [{ "type" => "see", "ref" => { "source" => "urn:oiml:pub:v:2:2012", "id" => "2.9" } }]
      kind, official = described_class.pick_official(edges)
      expect(kind).to eq("defined_in_vim")
      expect(official["source"]).to eq("urn:oiml:pub:v:2:2012")
      expect(official["id"]).to eq("2.9")
    end
  end

  describe ".merge_designations" do
    it "returns empty array for empty input" do
      expect(described_class.merge_designations([])).to eq([])
    end
  end

  describe ".merged_edges" do
    it "returns empty array when no instances" do
      expect(described_class.merged_edges([])).to eq([])
    end
  end
end
