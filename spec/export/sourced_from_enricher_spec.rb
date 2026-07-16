# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"
require_relative "../../lib/g18/export"

RSpec.describe G18::Export::SourcedFromEnricher do
  let(:vocab_root) { Dir.mktmpdir("vocab") }

  after { FileUtils.remove_entry(vocab_root) if File.exist?(vocab_root) }

  def write_complete_concept(id, designation, sources: [])
    dir = File.join(vocab_root, "oiml-complete", "concepts")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{id}.yaml"), [
      { "data" => { "localized_concepts" => { "eng" => "loc-#{id}" } } },
      {
        "data" => {
          "definition" => [{ "content" => "def" }],
          "terms" => [{ "designation" => designation, "normative_status" => "preferred", "type" => "expression" }],
          "sources" => sources,
        },
      },
    ].map(&:to_yaml).join)
  end

  it "is a no-op when the dataset dir does not exist" do
    e = described_class.new(vocab_root: "/nonexistent")
    terms = [{ "slug" => "x", "publications" => [] }]
    expect { e.call(terms) }.not_to raise_error
    expect(terms).to eq([{ "slug" => "x", "publications" => [] }])
  end

  it "adds sourced_from to matching publication instances" do
    write_complete_concept("001", "Calibration", sources: [
      { "sourced_from" => [{ "ref" => { "source" => "OIML D 11:2013", "id" => "3.4" } }] },
    ])
    e = described_class.new(vocab_root: vocab_root)
    terms = [{
      "slug" => "calibration",
      "publications" => [
        { "edition" => "complete", "publication_id" => "OIML R 1" },
      ],
    }]
    e.call(terms)
    # Note: the enricher only persists `source`, dropping `id`. This
    # matches the original script behavior.
    expect(terms.first["publications"].first["sourced_from"])
      .to eq([{ "source" => "OIML D 11:2013" }])
  end

  it "does not overwrite an existing sourced_from" do
    write_complete_concept("001", "Calibration", sources: [
      { "sourced_from" => [{ "ref" => { "source" => "OIML D 11:2013" } }] },
    ])
    e = described_class.new(vocab_root: vocab_root)
    terms = [{
      "slug" => "calibration",
      "publications" => [
        { "edition" => "complete", "publication_id" => "OIML R 1",
          "sourced_from" => [{ "source" => "EXISTING" }] },
      ],
    }]
    e.call(terms)
    expect(terms.first["publications"].first["sourced_from"]).to eq([{ "source" => "EXISTING" }])
  end

  it "only writes to instances with edition=complete" do
    write_complete_concept("001", "Calibration", sources: [
      { "sourced_from" => [{ "ref" => { "source" => "OIML D 11:2013" } }] },
    ])
    e = described_class.new(vocab_root: vocab_root)
    terms = [{
      "slug" => "calibration",
      "publications" => [
        { "edition" => "202X", "publication_id" => "OIML R 1" },
      ],
    }]
    e.call(terms)
    expect(terms.first["publications"].first["sourced_from"]).to be_nil
  end

  it "skips concepts without preferred designation" do
    # No 'terms' field — should not crash
    dir = File.join(vocab_root, "oiml-complete", "concepts")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "999.yaml"), [
      { "data" => { "localized_concepts" => {} } },
      { "data" => { "definition" => [{ "content" => "x" }] } },
    ].map(&:to_yaml).join)
    e = described_class.new(vocab_root: vocab_root)
    terms = [{ "slug" => "anything", "publications" => [] }]
    expect { e.call(terms) }.not_to raise_error
  end

  it "handles concepts without sources array" do
    write_complete_concept("001", "Calibration", sources: [])
    e = described_class.new(vocab_root: vocab_root)
    terms = [{
      "slug" => "calibration",
      "publications" => [{ "edition" => "complete", "publication_id" => "OIML R 1" }],
    }]
    e.call(terms)
    expect(terms.first["publications"].first["sourced_from"]).to be_nil
  end
end
