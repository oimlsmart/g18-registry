# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"
require_relative "../lib/g18/tc_sc_validate"

RSpec.describe G18::TcSc::Validate do
  let(:vocab_dir) { Dir.mktmpdir("vocab") }
  let(:local_path) { File.join(Dir.mktmpdir("local"), "publications.yaml") }

  after do
    FileUtils.remove_entry(vocab_dir) if File.exist?(vocab_dir)
    FileUtils.remove_entry(File.dirname(local_path)) if File.exist?(File.dirname(local_path))
  end

  def write_vocab(entries)
    File.write(File.join(vocab_dir, "bibliography.yaml"), entries.to_yaml)
  end

  def write_local(entries)
    File.write(local_path, entries.to_yaml)
  end

  describe ".call" do
    it "returns ok: true when local mirrors vocab exactly" do
      write_vocab([{ "id" => "X" }, { "id" => "Y" }])
      write_local([{ "id" => "X", "tc_sc" => "TC 9" }, { "id" => "Y", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      expect(result.ok).to be(true)
      expect(result.missing).to eq([])
      expect(result.extra).to eq([])
    end

    it "reports missing entries (in vocab but not local)" do
      write_vocab([{ "id" => "X" }, { "id" => "Y" }])
      write_local([{ "id" => "X", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      expect(result.ok).to be(false)
      expect(result.missing).to eq(["Y"])
    end

    it "reports extra entries (in local but not vocab)" do
      write_vocab([{ "id" => "X" }])
      write_local([{ "id" => "X", "tc_sc" => "" }, { "id" => "Y", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      expect(result.ok).to be(false)
      expect(result.extra).to eq(["Y"])
    end

    it "separates populated vs blank tc_sc entries" do
      write_vocab([{ "id" => "X" }, { "id" => "Y" }])
      write_local([{ "id" => "X", "tc_sc" => "TC 9" }, { "id" => "Y", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      expect(result.populated_tc_sc.map { |e| e["id"] }).to eq(["X"])
      expect(result.blank_tc_sc.map { |e| e["id"] }).to eq(["Y"])
    end

    it "counts total entries" do
      write_vocab([{ "id" => "X" }, { "id" => "Y" }, { "id" => "Z" }])
      write_local([{ "id" => "X", "tc_sc" => "" }, { "id" => "Y", "tc_sc" => "" }, { "id" => "Z", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      expect(result.total).to eq(3)
    end
  end

  describe ".render_report" do
    it "prints PASS when in sync" do
      write_vocab([{ "id" => "X" }])
      write_local([{ "id" => "X", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      sink = StringIO.new
      described_class.render_report(result, io: sink)
      expect(sink.string).to include("PASS")
    end

    it "prints FAIL when out of sync" do
      write_vocab([{ "id" => "X" }])
      write_local([{ "id" => "Y", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      sink = StringIO.new
      described_class.render_report(result, io: sink)
      expect(sink.string).to include("FAIL")
      expect(sink.string).to include("MISSING")
      expect(sink.string).to include("EXTRA")
    end

    it "returns the ok flag" do
      write_vocab([{ "id" => "X" }])
      write_local([{ "id" => "X", "tc_sc" => "" }])
      result = described_class.call(vocab_dir: vocab_dir, local_path: local_path)
      sink = StringIO.new
      returned = described_class.render_report(result, io: sink)
      expect(returned).to eq(result.ok)
    end
  end
end
