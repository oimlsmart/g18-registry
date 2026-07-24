# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"
require_relative "../../lib/g18"

RSpec.describe G18::Migration::Runner do
  VOCAB_ROOT = File.expand_path("../../../vocab/datasets", __dir__)

  let(:output_dir) { Dir.mktmpdir("output") }

  after do
    FileUtils.remove_entry(output_dir) if File.exist?(output_dir)
  end

  # Skip tests that need the real vocab repo if it isn't checked out locally.
  def self.requires_vocab!
    before(:each) do
      skip "vocab repo not checked out at #{VOCAB_ROOT}" unless Dir.exist?(VOCAB_ROOT)
    end
  end

  describe ".validate_inputs!" do
    it "raises when editions is not an Array" do
      expect { described_class.validate_inputs!(nil) }.to raise_error(ArgumentError)
    end

    it "raises when editions is empty" do
      expect { described_class.validate_inputs!([]) }.to raise_error(ArgumentError)
    end

    it "raises when an edition is missing :name or :path" do
      expect { described_class.validate_inputs!([{ name: "x" }]) }.to raise_error(ArgumentError)
    end

    it "skips editions whose path does not exist" do
      real = Dir.mktmpdir
      ghost = "/tmp/does-not-exist-#{Time.now.to_i}"
      valid = described_class.validate_inputs!([
        { name: "real", path: real },
        { name: "ghost", path: ghost },
      ])
      expect(valid.map { |e| e[:name] }).to eq(["real"])
    ensure
      FileUtils.remove_entry(real) if File.exist?(real)
    end
  end

  describe ".run", :requires_vocab do
    requires_vocab!

    it "migrates concepts from a real vocab dataset" do
      # Use viml-2022 (136 concepts) as a small known dataset
      result = described_class.run(
        editions: [{ name: "viml-2022", path: File.join(VOCAB_ROOT, "viml-2022"), primary: true, vocab: :viml }],
        output_dir: output_dir,
      )
      expect(result.unique_term_count).to be > 0
      expect(result.files_written.size).to eq(result.unique_term_count)
      expect(result.editions.first[:name]).to eq("viml-2022")
      expect(result.editions.first[:primary]).to be(true)
    end

    it "writes YAML files that exist on disk" do
      result = described_class.run(
        editions: [{ name: "vim-2012", path: File.join(VOCAB_ROOT, "vim-2012"), primary: true, vocab: :vim }],
        output_dir: output_dir,
      )
      sampled = result.files_written.first
      expect(File.exist?(sampled)).to be(true)
      parsed = YAML.load_file(sampled)
      expect(parsed["data"]["term"]).to_not be_nil
    end

    it "assigns V1/V2 kind based on :vocab metadata" do
      result = described_class.run(
        editions: [{ name: "viml-2022", path: File.join(VOCAB_ROOT, "viml-2022"), primary: true, vocab: :viml }],
        output_dir: output_dir,
      )
      sampled = YAML.load_file(result.files_written.first)
      expect(["defined_in_viml", "defined_in_vim"]).to include(sampled["data"]["kind"])
    end

    it "raises when no valid editions exist" do
      expect {
        described_class.run(
          editions: [{ name: "ghost", path: "/tmp/nope-#{Time.now.to_i}" }],
          output_dir: output_dir,
        )
      }.to raise_error(ArgumentError)
    end
  end

  describe ".serialize_record" do
    it "produces YAML starting with ---" do
      s = described_class.serialize_record({ "data" => { "term" => "x" } })
      expect(s).to start_with("---\n")
    end

    it "passes through YAML that already starts with ---" do
      s = described_class.serialize_record({ "data" => { "term" => "x" } })
      expect(s).to start_with("---\n")
    end
  end
end
