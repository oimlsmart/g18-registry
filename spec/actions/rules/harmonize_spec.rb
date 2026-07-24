# frozen_string_literal: true

require_relative "../../../lib/g18"

RSpec.describe G18::Actions::Rules::Harmonize do
  def state(pubs:)
    G18::Actions::TermState.new(term: { "data" => { "publications" => pubs } })
  end

  it "fires when ≥ 2 distinct defs in same edition" do
    pubs = [
      { "publication_id" => "A", "edition" => "202X", "definition" => "def 1" },
      { "publication_id" => "B", "edition" => "202X", "definition" => "def 2" },
    ]
    actions = described_class.call(state(pubs: pubs))
    expect(actions.first.type).to eq(:harmonize)
    expect(actions.first.priority).to eq(:low)
  end

  it "is high priority when ≥ 5 distinct defs" do
    pubs = (1..5).map do |i|
      { "publication_id" => "P#{i}", "edition" => "202X", "definition" => "def #{i}" }
    end
    expect(described_class.call(state(pubs: pubs)).first.priority).to eq(:high)
  end

  it "is medium priority when ≥ 3 distinct defs" do
    pubs = (1..3).map do |i|
      { "publication_id" => "P#{i}", "edition" => "202X", "definition" => "def #{i}" }
    end
    expect(described_class.call(state(pubs: pubs)).first.priority).to eq(:medium)
  end

  it "does NOT fire when defs differ only across editions" do
    pubs = [
      { "publication_id" => "A", "edition" => "202X", "definition" => "202X wording" },
      { "publication_id" => "B", "edition" => "2010", "definition" => "2010 wording" },
    ]
    expect(described_class.call(state(pubs: pubs))).to eq([])
  end

  it "returns empty for fewer than 2 pubs" do
    expect(described_class.call(state(pubs: [{ "edition" => "202X", "definition" => "only" }]))).to eq([])
  end

  it "publishes publication_ids scoped to the worst edition" do
    pubs = [
      { "publication_id" => "A", "edition" => "202X", "definition" => "x" },
      { "publication_id" => "B", "edition" => "202X", "definition" => "y" },
      { "publication_id" => "C", "edition" => "2010", "definition" => "z" },
    ]
    action = described_class.call(state(pubs: pubs)).first
    expect(action.publication_ids).to contain_exactly("A", "B")
  end
end
