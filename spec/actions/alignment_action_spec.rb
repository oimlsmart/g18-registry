# frozen_string_literal: true

require_relative "../../lib/g18"

RSpec.describe G18::Actions::Compiler, "#alignment_action" do
  def compile(alignment: nil, kind: "oiml_original", **opts)
    described_class.for_term(
      "data" => { "kind" => kind, "term" => "test", "publications" => [], **opts },
      "alignment" => alignment,
    ).map { |a| a.to_h }
  end

  it "produces aligned action for case 1" do
    actions = compile(alignment: { "case" => 1, "alignment" => "aligned", "matched_vocab" => "vim" })
    expect(actions.any? { |a| a["type"] == "aligned" }).to be true
  end

  it "produces definition_diverges action for case 3" do
    actions = compile(alignment: { "case" => 3, "alignment" => "diverges", "matched_vocab" => "viml" })
    expect(actions.any? { |a| a["type"] == "definition_diverges" }).to be true
  end

  it "produces fuzzy_adopt action for case 4" do
    actions = compile(alignment: { "case" => 4, "alignment" => "fuzzy", "matched_vocab" => "vim" })
    expect(actions.any? { |a| a["type"] == "fuzzy_adopt" }).to be true
  end

  it "produces propose_v3 action for case 5" do
    actions = compile(alignment: { "case" => 5, "alignment" => "none", "matched_vocab" => nil })
    expect(actions.any? { |a| a["type"] == "propose_v3" }).to be true
  end

  it "produces no alignment action when alignment is nil" do
    actions = compile(alignment: nil)
    expect(actions.none? { |a| ["aligned", "definition_diverges", "fuzzy_adopt", "propose_v3"].include?(a["type"]) })
      .to be true
  end

  it "aligned action has info priority" do
    actions = compile(alignment: { "case" => 1, "alignment" => "aligned", "matched_vocab" => "vim" })
    aligned = actions.find { |a| a["type"] == "aligned" }
    expect(aligned["priority"]).to eq("info")
  end

  it "definition_diverges action has high priority" do
    actions = compile(alignment: { "case" => 3, "alignment" => "diverges", "matched_vocab" => "viml" })
    diverges = actions.find { |a| a["type"] == "definition_diverges" }
    expect(diverges["priority"]).to eq("high")
  end

  it "includes VIML label when matched_vocab is viml" do
    actions = compile(alignment: { "case" => 3, "alignment" => "diverges", "matched_vocab" => "viml" })
    diverges = actions.find { |a| a["type"] == "definition_diverges" }
    expect(diverges["description"]).to include("VIML 2022")
  end

  it "includes VIM label when matched_vocab is vim" do
    actions = compile(alignment: { "case" => 1, "alignment" => "aligned", "matched_vocab" => "vim" })
    aligned = actions.find { |a| a["type"] == "aligned" }
    expect(aligned["description"]).to include("VIM 2012")
  end
end
