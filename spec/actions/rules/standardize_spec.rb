# frozen_string_literal: true

require_relative "../../../lib/g18"

RSpec.describe G18::Actions::Rules::Standardize do
  def state(pubs:)
    G18::Actions::TermState.new(term: { "data" => { "publications" => pubs } })
  end

  it "fires when ≥ 2 pubs share identical definition" do
    pubs = [
      { "publication_id" => "A", "edition" => "202X", "definition" => "same" },
      { "publication_id" => "B", "edition" => "2010", "definition" => "same" },
    ]
    actions = described_class.call(state(pubs: pubs))
    expect(actions.first.type).to eq(:standardize)
    expect(actions.first.description).to include("2 publications")
  end

  it "mentions '1 publication across N editions' when only one unique pub" do
    pubs = [
      { "publication_id" => "A", "edition" => "202X", "definition" => "same" },
      { "publication_id" => "A", "edition" => "2010", "definition" => "same" },
    ]
    expect(described_class.call(state(pubs: pubs)).first.description).to include("Cited by 1 publication across 2 editions")
  end

  it "does NOT fire when defs differ" do
    pubs = [
      { "publication_id" => "A", "edition" => "202X", "definition" => "x" },
      { "publication_id" => "B", "edition" => "202X", "definition" => "y" },
    ]
    expect(described_class.call(state(pubs: pubs))).to eq([])
  end

  it "returns empty for fewer than 2 pubs" do
    expect(described_class.call(state(pubs: [{ "edition" => "x", "definition" => "y" }]))).to eq([])
  end
end
