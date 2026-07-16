# frozen_string_literal: true

require_relative "../../lib/g18/migration/result"

RSpec.describe G18::Migration::Result do
  it "is a Struct with the expected fields" do
    expect(described_class.members).to contain_exactly(
      :files_written, :instance_count, :unique_term_count,
      :related_edge_count, :per_instance_edge_count, :multi_edge_terms,
      :slug_collisions, :annotations_stripped, :alias_merges,
      :id_conflicts, :editions
    )
  end

  it "supports keyword construction" do
    r = described_class.new(files_written: ["a.yaml"], instance_count: 1, unique_term_count: 1)
    expect(r.files_written).to eq(["a.yaml"])
    expect(r.unique_term_count).to eq(1)
  end
end
