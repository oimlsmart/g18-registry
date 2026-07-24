# frozen_string_literal: true

require_relative "../../lib/g18"

RSpec.describe G18::Migration::Loaders, "source_origin_*" do
  describe ".source_origin_source" do
    it "returns the ref string directly for new vocab v3 shape (ref: <string>)" do
      src = { "origin" => { "ref" => "OIML R 49-1:2003 (E)" } }
      expect(described_class.source_origin_source(src)).to eq("OIML R 49-1:2003 (E)")
    end

    it "returns ref.source for legacy shape (ref: {source:, id:})" do
      src = { "origin" => { "ref" => { "source" => "OIML R 49-1:2003 (E)", "id" => "3.1" } } }
      expect(described_class.source_origin_source(src)).to eq("OIML R 49-1:2003 (E)")
    end

    it "returns nil when ref is missing" do
      src = { "origin" => {} }
      expect(described_class.source_origin_source(src)).to be_nil
    end

    it "returns nil when origin is missing" do
      src = {}
      expect(described_class.source_origin_source(src)).to be_nil
    end

    it "returns nil for nil ref" do
      src = { "origin" => { "ref" => nil } }
      expect(described_class.source_origin_source(src)).to be_nil
    end
  end

  describe ".source_origin_id" do
    it "returns nil for new vocab v3 shape (string ref has no id)" do
      src = { "origin" => { "ref" => "OIML R 49-1:2003 (E)" } }
      expect(described_class.source_origin_id(src)).to be_nil
    end

    it "returns ref.id for legacy shape" do
      src = { "origin" => { "ref" => { "source" => "OIML R 49-1:2003 (E)", "id" => "3.1" } } }
      expect(described_class.source_origin_id(src)).to eq("3.1")
    end

    it "returns nil when ref is missing" do
      src = { "origin" => {} }
      expect(described_class.source_origin_id(src)).to be_nil
    end
  end
end
