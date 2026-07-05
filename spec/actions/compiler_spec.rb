# frozen_string_literal: true

require_relative "../../lib/g18/actions"

RSpec.describe G18::Actions::Compiler do
  let(:base_term) do
    {
      "data" => {
        "identifier" => "00100",
        "term" => "test term",
        "kind" => "defined_in_vim",
        "official_concept" => {
          "source" => "urn:oiml:pub:v:2:2007",
          "id" => "4.11",
          "edition_label" => "VIM 2007",
        },
        "publications" => [
          { "publication_id" => "OIML R076-1:2009", "definition" => "test definition", "tc_sc" => "TC9/SC1" },
        ],
      },
      "latest_check" => { "found" => true, "vocab" => "vim", "latest_label" => "VIM 2012" },
    }
  end

  describe ".for_term" do
    it "returns upgrade_vim action when citing superseded VIM" do
      actions = described_class.for_term(base_term)
      upgrade = actions.find { |a| a.type == :upgrade_vim }
      expect(upgrade).not_to be_nil
      expect(upgrade.priority).to eq(:high)
      expect(upgrade.description).to include("VIM 2007")
      expect(upgrade.description).to include("VIM 2012")
    end

    it "returns removed action when not found in latest" do
      term = base_term.dup
      term["latest_check"] = { "found" => false, "vocab" => "vim", "latest_label" => "VIM 2012" }
      actions = described_class.for_term(term)
      removed = actions.find { |a| a.type == :removed }
      expect(removed).not_to be_nil
      expect(removed.description).to include("removed from VIM 2012")
    end

    it "returns harmonize action when definitions diverge within an edition" do
      term = base_term.dup
      term["data"]["publications"] = [
        { "publication_id" => "OIML R076-1:2009", "definition" => "definition A", "edition" => "202X" },
        { "publication_id" => "OIML R050-1:2014", "definition" => "definition B", "edition" => "202X" },
      ]
      actions = described_class.for_term(term)
      harm = actions.find { |a| a.type == :harmonize }
      expect(harm).not_to be_nil
      expect(harm.description).to include("2 distinct definitions within 202X")
    end

    it "does NOT flag harmonize when defs differ only across editions" do
      term = base_term.dup
      term["data"]["publications"] = [
        { "publication_id" => "OIML R049-2:2006", "definition" => "2010 wording", "edition" => "2010" },
        { "publication_id" => "OIML R049-1:2024", "definition" => "202X wording", "edition" => "202X" },
      ]
      actions = described_class.for_term(term)
      harm = actions.find { |a| a.type == :harmonize }
      expect(harm).to be_nil
    end

    it "returns standardize action when all definitions match" do
      term = base_term.dup
      term["data"]["publications"] = [
        { "publication_id" => "OIML R076-1:2009", "definition" => "same def" },
        { "publication_id" => "OIML R050-1:2014", "definition" => "same def" },
      ]
      term["latest_check"] = nil
      term["data"]["official_concept"] = nil
      actions = described_class.for_term(term)
      std = actions.find { |a| a.type == :standardize }
      expect(std).not_to be_nil
      expect(std.priority).to eq(:info)
    end

    it "returns unique action for OIML-original terms" do
      term = {
        "data" => {
          "identifier" => "00200",
          "term" => "unique term",
          "kind" => "undefined",
          "publications" => [
            { "publication_id" => "OIML R076-1:2009", "definition" => "def" },
          ],
        },
      }
      actions = described_class.for_term(term)
      unique = actions.find { |a| a.type == :unique }
      expect(unique).not_to be_nil
    end

    it "normalizes {{id,text}} cross-references before comparing" do
      term = base_term.dup
      term["data"]["publications"] = [
        { "publication_id" => "OIML R076-1:2009", "definition" => "test {{1.1,measuring instrument}} def" },
        { "publication_id" => "OIML R050-1:2014", "definition" => "test measuring instrument def" },
      ]
      term["latest_check"] = nil
      term["data"]["official_concept"] = nil
      actions = described_class.for_term(term)
      std = actions.find { |a| a.type == :standardize }
      expect(std).not_to be_nil
    end

    it "sorts actions by priority" do
      term = base_term.dup
      term["data"]["publications"] = [
        { "publication_id" => "A", "definition" => "def A" },
        { "publication_id" => "B", "definition" => "def B" },
        { "publication_id" => "C", "definition" => "def C" },
        { "publication_id" => "D", "definition" => "def D" },
        { "publication_id" => "E", "definition" => "def E" },
      ]
      actions = described_class.for_term(term)
      expect(actions.first.priority_rank).to be <= actions.last.priority_rank
    end
  end
end

RSpec.describe G18::Actions::Action do
  it "is immutable (frozen)" do
    action = described_class.new(type: :unique, priority: :info, description: "test")
    expect(action.frozen?).to be true
  end

  it "raises on unknown type" do
    expect {
      described_class.new(type: :bogus, priority: :high, description: "x")
    }.to raise_error(ArgumentError)
  end

  it "serializes to hash" do
    action = described_class.new(type: :harmonize, priority: :medium, description: "test")
    h = action.to_h
    expect(h["type"]).to eq("harmonize")
    expect(h["priority"]).to eq("medium")
  end
end
