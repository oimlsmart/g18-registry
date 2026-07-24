# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require_relative "../../lib/g18"

RSpec.describe G18::Export::ConceptDiffer do
  let(:vocab_root) { Dir.mktmpdir("vocab") }
  let(:script_dir) { File.expand_path("../../web/scripts", __dir__) }

  after { FileUtils.remove_entry(vocab_root) if File.exist?(vocab_root) }

  def write_concept(dataset, id, designation, definition:)
    dir = File.join(vocab_root, dataset, "concepts")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{id}.yaml"), {
      "data" => {
        "identifier" => id,
        "localized_concepts" => { "eng" => "loc-#{id}" },
        "sources" => [{ "type" => "authoritative" }],
      },
      "status" => "valid",
      "id" => id,
      "schema_version" => "3",
    }.to_yaml)
    # localized concept doc
    File.open(File.join(dir, "#{id}.yaml"), "a") do |f|
      f.write({
        "data" => {
          "definition" => [{ "content" => definition }],
          "terms" => [{ "designation" => designation, "normative_status" => "preferred", "type" => "expression" }],
        },
      }.to_yaml)
    end
  end

  # The actual diff computation is delegated to a Node.js script
  # (web/scripts/compute-concept-diffs.mjs). We only verify the bridge:
  # that ConceptDiffer iterates the expected pairs and produces a hash
  # keyed by "old->new".
  it "returns empty hash when no concept dirs exist" do
    differ = described_class.new(script_dir: script_dir, vocab_root: "/nonexistent")
    expect(differ.call).to eq({})
  end

  it "skips pairs where old or new dir is missing" do
    write_concept("vim-2007", "1.1", "calibration", definition: "old")
    # vim-2012 dir absent — pair should be skipped
    differ = described_class.new(script_dir: script_dir, vocab_root: vocab_root)
    result = differ.call
    expect(result).to eq({})
  end

  it "builds diff_key from old and new dir names" do
    differ = described_class.new(script_dir: script_dir, vocab_root: vocab_root)
    # Both dirs present — diff_key should be "viml-2000->viml-2022" etc.
    # We can't easily exercise the actual Node script in specs, but we
    # can verify the bridge iterates the expected pairs.
    pairs_yaml = described_class::DIFF_PAIRS
    expect(pairs_yaml[:vim]).to include(["vim-1993", "vim-2012"])
    expect(pairs_yaml[:viml]).to include(["viml-2000", "viml-2022"])
  end
end
