# frozen_string_literal: true

require_relative "../../../lib/g18"

RSpec.describe G18::Actions::Rules::Alignment do
  def state(alignment:, vocab_presence: {})
    G18::Actions::TermState.new(term: {
      "data" => { "term" => "test", "kind" => "oiml_original", "publications" => [] },
      "alignment" => alignment,
      "vocab_presence" => vocab_presence,
    })
  end

  it "produces aligned for case 1" do
    actions = described_class.call(state(alignment: { "case" => 1, "alignment" => "aligned", "matched_vocab" => "vim" }))
    expect(actions.first.type).to eq(:aligned)
    expect(actions.first.priority).to eq(:info)
  end

  it "produces definition_diverges for case 3 with high priority" do
    actions = described_class.call(state(alignment: { "case" => 3, "alignment" => "diverges", "matched_vocab" => "viml" }))
    expect(actions.first.type).to eq(:definition_diverges)
    expect(actions.first.priority).to eq(:high)
    expect(actions.first.description).to include("VIML 2022")
  end

  it "produces fuzzy_adopt for case 4 with matched designation in description" do
    actions = described_class.call(state(
      alignment: { "case" => 4, "alignment" => "fuzzy", "matched_vocab" => "viml" },
      vocab_presence: { "viml" => { "designation" => "near miss" } },
    ))
    expect(actions.first.type).to eq(:fuzzy_adopt)
    expect(actions.first.description).to include("'near miss'")
  end

  it "produces propose_v3 for case 5" do
    actions = described_class.call(state(alignment: { "case" => 5, "alignment" => "none", "matched_vocab" => nil }))
    expect(actions.first.type).to eq(:propose_v3)
    expect(actions.first.description).to include("'test'")
  end

  it "returns empty array when alignment is nil" do
    expect(described_class.call(G18::Actions::TermState.new(term: { "data" => {} }))).to eq([])
  end

  it "returns empty array for unknown case" do
    actions = described_class.call(state(alignment: { "case" => 99, "alignment" => "?", "matched_vocab" => nil }))
    expect(actions).to eq([])
  end

  it "uses 'V1/V2' label when matched_vocab is neither vim nor viml" do
    actions = described_class.call(state(alignment: { "case" => 1, "alignment" => "aligned", "matched_vocab" => nil }))
    expect(actions.first.description).to include("V1/V2")
  end
end
