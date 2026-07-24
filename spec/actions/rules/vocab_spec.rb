# frozen_string_literal: true

require_relative "../../../lib/g18"

RSpec.describe G18::Actions::Rules::Vocab do
  def state(lc:, oc: { "source" => "urn:oiml:pub:v:2:2007", "id" => "2.9" }, mismatch: nil, pubs: [])
    G18::Actions::TermState.new(term: {
      "data" => { "publications" => pubs, "official_concept" => oc },
      "latest_check" => lc,
      "canonical_mismatch" => mismatch,
    })
  end

  it "returns upgrade_vim when found in current VIM but citing old VIM" do
    actions = described_class.call(state(
      lc: { "found" => true, "vocab" => "vim", "latest_label" => "VIM 2012", "concept_id" => "2.9" },
      pubs: [{ "publication_id" => "P1" }],
    ))
    expect(actions.first.type).to eq(:upgrade_vim)
    expect(actions.first.priority).to eq(:high)
    expect(actions.first.description).to include("VIM reference outdated")
  end

  it "returns upgrade_viml when found in current VIML but citing old VIML" do
    actions = described_class.call(state(
      lc: { "found" => true, "vocab" => "viml", "latest_label" => "VIML 2022" },
      oc: { "source" => "urn:oiml:pub:v:1:2013" },
      pubs: [{ "publication_id" => "P1" }],
    ))
    expect(actions.first.type).to eq(:upgrade_viml)
  end

  it "returns removed when not in latest, without mismatch" do
    actions = described_class.call(state(
      lc: { "found" => false, "vocab" => "vim", "latest_label" => "VIM 2012" },
      pubs: [{ "publication_id" => "P1" }],
    ))
    expect(actions.first.type).to eq(:removed)
    expect(actions.first.description).to include("Verify or reallocate")
  end

  it "returns removed with rename suggestion when mismatch is set" do
    actions = described_class.call(state(
      lc: { "found" => false, "vocab" => "viml", "latest_label" => "VIML 2022" },
      oc: { "source" => "urn:oiml:pub:v:1:2013" },
      mismatch: { "latest_label" => "VIML 2022", "designation" => "new name" },
      pubs: [{ "publication_id" => "P1" }],
    ))
    expect(actions.first.type).to eq(:removed)
    expect(actions.first.description).to include("new name")
    expect(actions.first.description).to include("Verify rename")
  end

  it "adds divergence tail when has_divergence is true" do
    actions = described_class.call(state(
      lc: { "found" => false, "vocab" => "vim", "latest_label" => "VIM 2012" },
      pubs: [
        { "publication_id" => "A", "edition" => "202X", "definition" => "x" },
        { "publication_id" => "B", "edition" => "202X", "definition" => "y" },
      ],
    ))
    expect(actions.first.description).to include("document why divergence is intentional")
  end

  it "returns empty when latest_check is nil" do
    expect(described_class.call(G18::Actions::TermState.new(term: { "data" => {} }))).to eq([])
  end

  it "returns empty when official_concept is nil" do
    state = G18::Actions::TermState.new(term: {
      "data" => {},
      "latest_check" => { "found" => true, "vocab" => "vim", "latest_label" => "VIM 2012" },
    })
    expect(described_class.call(state)).to eq([])
  end
end
