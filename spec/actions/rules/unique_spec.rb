# frozen_string_literal: true

require_relative "../../../lib/g18"

RSpec.describe G18::Actions::Rules::Unique do
  def state(kind: "oiml_original", vocab_presence: {}, pubs: [], official_concept: nil)
    G18::Actions::TermState.new(term: {
      "data" => {
        "kind" => kind, "publications" => pubs, "official_concept" => official_concept,
      },
      "vocab_presence" => vocab_presence,
    })
  end

  it "fires for oiml_original with no near-miss" do
    actions = described_class.call(state(vocab_presence: {}))
    expect(actions.first.type).to eq(:unique)
    expect(actions.first.description).to include("Not in VIML/VIM")
    expect(actions.first.description).to include("V 1/V 2/V 3?")
  end

  it "fires for kind=undefined (legacy)" do
    expect(described_class.call(state(kind: "undefined")).first.type).to eq(:unique)
  end

  it "does NOT fire for defined_in_vim with official_concept" do
    expect(described_class.call(state(
      kind: "defined_in_vim",
      official_concept: { "source" => "urn:oiml:pub:v:2:2012" },
    ))).to eq([])
  end

  it "mentions exact match when vocab_presence has match_type=exact" do
    actions = described_class.call(state(vocab_presence: {
      "viml" => { "match_type" => "exact", "designation" => "Verifying", "latest_label" => "VIML 2022" },
    }))
    expect(actions.first.description).to include("exact match")
    expect(actions.first.description).to include("'Verifying'")
    expect(actions.first.description).to include("VIML 2022")
  end

  it "mentions similar term when match_type=fuzzy" do
    actions = described_class.call(state(vocab_presence: {
      "vim" => { "match_type" => "fuzzy", "designation" => "Calibration", "latest_label" => "VIM 2012" },
    }))
    expect(actions.first.description).to include("similar term")
    expect(actions.first.description).to include("'Calibration'")
  end

  it "prefers VIML match over VIM when both present" do
    actions = described_class.call(state(vocab_presence: {
      "viml" => { "match_type" => "fuzzy", "designation" => "VIML term", "latest_label" => "VIML 2022" },
      "vim"  => { "match_type" => "fuzzy", "designation" => "VIM term",  "latest_label" => "VIM 2012" },
    }))
    expect(actions.first.description).to include("'VIML term'")
  end

  it "adds divergence tail when has_divergence is true" do
    pubs = [
      { "publication_id" => "A", "edition" => "202X", "definition" => "x" },
      { "publication_id" => "B", "edition" => "202X", "definition" => "y" },
    ]
    actions = described_class.call(state(pubs: pubs))
    expect(actions.first.description).to include("Check divergent definitions")
  end
end
