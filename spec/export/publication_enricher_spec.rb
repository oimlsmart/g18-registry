# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "../../lib/g18/export"

RSpec.describe G18::Export::PublicationEnricher do
  let(:vocab_root) { Dir.mktmpdir("vocab") }
  let(:relaton_root) { Dir.mktmpdir("relaton") }

  after do
    FileUtils.remove_entry(vocab_root) if File.exist?(vocab_root)
    FileUtils.remove_entry(relaton_root) if File.exist?(relaton_root)
  end

  def write_bib(dataset, docs)
    dir = File.join(vocab_root, dataset)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "bibliography.yaml"), docs.to_yaml)
  end

  def write_relaton_index(entries)
    File.write(File.join(relaton_root, "index-v2.yaml"), entries.to_yaml)
  end

  def write_relaton_doc(file, body)
    path = File.join(relaton_root, file)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body.to_yaml)
  end

  it "loads publications from oiml-complete bibliography" do
    write_bib("oiml-complete", [{ "id" => "OIML R 1:2020" }, { "id" => "OIML R 2:2020" }])
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    expect(result.publications.map { |p| p["id"] }).to contain_exactly("OIML R 1:2020", "OIML R 2:2020")
  end

  it "dedups across bib files by id" do
    write_bib("oiml-complete", [{ "id" => "OIML R 1:2020" }])
    write_bib("g18-202X",     [{ "id" => "OIML R 1:2020" }, { "id" => "OIML R 2:2020" }])
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    expect(result.publications.size).to eq(2)
  end

  it "enriches TC/SC from relaton contributors" do
    write_bib("oiml-complete", [{ "id" => "OIML R 1:2020" }])
    write_relaton_index([
      { "id" => { "_type" => "pubid:oiml:recommendation", "publisher" => "OIML", "number" => "1", "year" => 2020 },
        "file" => "oiml-r-1-2020.yaml" },
    ])
    write_relaton_doc("oiml-r-1-2020.yaml", {
      "contributor" => [{
        "organization" => {
          "subdivision" => [
            { "type" => "technical-committee", "identifier" => [{ "content" => "TC 9" }] },
          ],
        },
      }],
    })
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    expect(result.publications.first["tc_sc"]).to eq("TC 9")
    expect(result.tc_sc_map["OIML R 1:2020"]).to eq("TC 9")
  end

  it "marks withdrawn publications" do
    write_bib("oiml-complete", [{ "id" => "OIML R 1:2020" }])
    write_relaton_index([
      { "id" => { "_type" => "pubid:oiml:recommendation", "publisher" => "OIML", "number" => "1", "year" => 2020 },
        "file" => "oiml-r-1-2020.yaml" },
    ])
    write_relaton_doc("oiml-r-1-2020.yaml", { "status" => { "stage" => "withdrawn" } })
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    expect(result.publications.first["withdrawn"]).to be(true)
    expect(result.withdrawn_set).to include("OIML R 1:2020")
  end

  it "computes lifecycle: latest non-withdrawn edition is current" do
    write_bib("oiml-complete", [
      { "id" => "OIML R 1:2010" },
      { "id" => "OIML R 1:2015" },
      { "id" => "OIML R 1:2020" },
    ])
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    lc = result.lifecycle_map
    expect(lc["OIML R 1:2010"]).to eq("retired")
    expect(lc["OIML R 1:2015"]).to eq("retired")
    expect(lc["OIML R 1:2020"]).to eq("current")
  end

  it "computes lifecycle: withdrawn stays withdrawn even if newest" do
    write_bib("oiml-complete", [
      { "id" => "OIML R 1:2010" },
      { "id" => "OIML R 1:2020", "withdrawn" => true },
    ])
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    expect(result.lifecycle_map["OIML R 1:2010"]).to eq("current")
    expect(result.lifecycle_map["OIML R 1:2020"]).to eq("withdrawn")
  end

  it "converts pubid:oiml:amendment into +Amendment:YEAR suffix" do
    write_bib("oiml-complete", [{ "id" => "OIML R 1:2020+Amendment:2021" }])
    write_relaton_index([
      { "id" => { "_type" => "pubid:oiml:amendment",
                  "base_identifier" => { "_type" => "pubid:oiml:recommendation",
                                          "publisher" => "OIML", "number" => "1", "year" => 2020 },
                  "year" => 2021 },
        "file" => "oiml-r-1-2020-amd1.yaml" },
    ])
    write_relaton_doc("oiml-r-1-2020-amd1.yaml", { "status" => { "stage" => "published" } })
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    expect(result.publications.first["id"]).to eq("OIML R 1:2020+Amendment:2021")
  end

  it "skips language-suffixed entries (E)/(F) when mapping" do
    write_bib("oiml-complete", [{ "id" => "OIML R 1:2020" }])
    write_relaton_index([
      # Language-suffixed entry should NOT be used
      { "id" => { "_type" => "pubid:oiml:recommendation", "publisher" => "OIML",
                  "number" => "1", "year" => 2020, "language" => "E" },
        "file" => "skip-this.yaml" },
    ])
    result = described_class.new(vocab_root: vocab_root, relaton_root: relaton_root).call
    # Publication exists but tc_sc not enriched because language-suffixed was skipped
    expect(result.publications.first["tc_sc"]).to be_nil
  end
end
