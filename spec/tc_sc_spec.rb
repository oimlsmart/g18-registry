# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"
require_relative "../lib/g18/tc_sc"

RSpec.describe G18::TcSc do
  let(:vocab_dir) { Dir.mktmpdir("vocab") }
  let(:local_path) { File.join(Dir.mktmpdir("local"), "publications.yaml") }

  after do
    FileUtils.remove_entry(vocab_dir) if File.exist?(vocab_dir)
    FileUtils.remove_entry(File.dirname(local_path)) if File.exist?(File.dirname(local_path))
  end

  def write_vocab_bib(entries)
    File.write(File.join(vocab_dir, "bibliography.yaml"), entries.to_yaml)
  end

  describe ".load_vocab_bibliography" do
    it "loads entries keyed by id" do
      write_vocab_bib([
        { "id" => "OIML R 1:2020", "reference" => "OIML R 1" },
        { "id" => "OIML R 2:2020", "reference" => "OIML R 2" },
      ])
      result = described_class.load_vocab_bibliography(vocab_dir)
      expect(result.keys).to contain_exactly("OIML R 1:2020", "OIML R 2:2020")
      expect(result["OIML R 1:2020"]["reference"]).to eq("OIML R 1")
    end

    it "raises Errno::ENOENT when the bibliography path doesn't exist" do
      # Document actual behavior: load_vocab_bibliography does NOT gracefully
      # handle missing paths — it lets File.read raise. Callers must check.
      expect { described_class.load_vocab_bibliography("/nonexistent") }
        .to raise_error(Errno::ENOENT)
    end

    it "returns empty hash when YAML is empty" do
      write_vocab_bib(nil)
      expect(described_class.load_vocab_bibliography(vocab_dir)).to eq({})
    end
  end

  describe ".load_local" do
    it "returns empty hash when file does not exist" do
      expect(described_class.load_local("/does/not/exist.yaml")).to eq({})
    end

    it "loads array-form YAML" do
      File.write(local_path, [{ "id" => "X", "tc_sc" => "TC 9" }].to_yaml)
      result = described_class.load_local(local_path)
      expect(result["X"]["tc_sc"]).to eq("TC 9")
    end

    it "loads single-document YAML" do
      File.write(local_path, { "id" => "X", "tc_sc" => "TC 9" }.to_yaml)
      result = described_class.load_local(local_path)
      expect(result["X"]["tc_sc"]).to eq("TC 9")
    end

    it "ignores non-Hash entries" do
      File.write(local_path, ["not a hash", { "id" => "X" }].to_yaml)
      result = described_class.load_local(local_path)
      expect(result.keys).to eq(["X"])
    end
  end

  describe ".merge" do
    it "preserves existing tc_sc values from local" do
      vocab = { "X" => { "id" => "X", "reference" => "X" } }
      local = { "X" => { "id" => "X", "tc_sc" => "TC 9/SC 1" } }
      merged = described_class.merge(vocab, local)
      expect(merged.first["tc_sc"]).to eq("TC 9/SC 1")
    end

    it "falls back to KNOWN_TC_SC when local is blank" do
      vocab = { "B 10-1" => { "id" => "B 10-1", "reference" => "OIML B 10-1:2004" } }
      local = {}
      merged = described_class.merge(vocab, local)
      expect(merged.first["tc_sc"]).to eq("TC 3/SC 2")
    end

    it "leaves tc_sc blank when no source has it" do
      vocab = { "X" => { "id" => "X", "reference" => "X" } }
      local = {}
      merged = described_class.merge(vocab, local)
      expect(merged.first["tc_sc"]).to eq("")
    end

    it "preserves local notes" do
      vocab = { "X" => { "id" => "X", "reference" => "X" } }
      local = { "X" => { "id" => "X", "tc_sc" => "TC 9", "notes" => "uncertain" } }
      merged = described_class.merge(vocab, local)
      expect(merged.first["notes"]).to eq("uncertain")
    end

    it "sorts entries by id" do
      vocab = {
        "Z" => { "id" => "Z", "reference" => "Z" },
        "A" => { "id" => "A", "reference" => "A" },
      }
      merged = described_class.merge(vocab, {})
      expect(merged.map { |e| e["id"] }).to eq(["A", "Z"])
    end

    it "uses id as reference when missing" do
      vocab = { "X" => { "id" => "X" } }
      merged = described_class.merge(vocab, {})
      expect(merged.first["reference"]).to eq("X")
    end
  end

  describe ".serialize" do
    it "produces YAML with a documentation header" do
      yaml = described_class.serialize([{ "id" => "X", "reference" => "X", "link" => nil, "tc_sc" => "", "notes" => "" }])
      expect(yaml).to start_with("# TC/SC attribution for OIML publications")
      expect(yaml).to include("Regenerate with: scripts/sync_tc_sc.rb")
    end

    it "includes all entry fields" do
      yaml = described_class.serialize([{ "id" => "X", "reference" => "X", "link" => "https://x", "tc_sc" => "TC 9", "notes" => "n" }])
      # serialize emits a single YAML doc containing an array of entries
      parsed = YAML.load(yaml)
      entry = parsed.first
      expect(entry["id"]).to eq("X")
      expect(entry["tc_sc"]).to eq("TC 9")
      expect(entry["link"]).to eq("https://x")
      expect(entry["notes"]).to eq("n")
    end
  end

  describe ".sync" do
    it "writes a populated YAML file and returns stats" do
      write_vocab_bib([
        { "id" => "OIML B 10-1:2004", "reference" => "OIML B 10-1:2004" },
        { "id" => "OIML R 1:2020", "reference" => "OIML R 1" },
      ])
      stats = described_class.sync(vocab_dir: vocab_dir, output_path: local_path)
      expect(File.exist?(local_path)).to be(true)
      expect(stats[:total]).to eq(2)
      expect(stats[:populated]).to eq(1) # B 10-1 from KNOWN_TC_SC
      expect(stats[:blank]).to eq(1)
    end

    it "preserves existing tc_sc values across re-syncs" do
      write_vocab_bib([{ "id" => "X", "reference" => "X" }])
      described_class.sync(vocab_dir: vocab_dir, output_path: local_path)
      # Manually edit the first entry's tc_sc
      parsed = YAML.load(File.read(local_path))
      parsed.first["tc_sc"] = "TC 9"
      File.write(local_path, parsed.to_yaml)
      # Re-sync
      described_class.sync(vocab_dir: vocab_dir, output_path: local_path)
      parsed2 = YAML.load(File.read(local_path))
      expect(parsed2.first["tc_sc"]).to eq("TC 9")
    end
  end

  describe "KNOWN_TC_SC" do
    it "is a frozen hash" do
      expect(described_class::KNOWN_TC_SC).to be_frozen
    end

    it "contains B 10 series mappings" do
      expect(described_class::KNOWN_TC_SC).to include("OIML B 10-1:2004" => "TC 3/SC 2")
    end
  end
end
