# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require_relative "../../lib/g18"

RSpec.describe G18::Export::JsonWriter do
  let(:out_dir) { Dir.mktmpdir("out") }
  let(:repo_root) { Dir.mktmpdir("repo") }
  let(:writer) { described_class.new(out_dir: out_dir, repo_root: repo_root) }

  after do
    FileUtils.remove_entry(out_dir) if File.exist?(out_dir)
    FileUtils.remove_entry(repo_root) if File.exist?(repo_root)
  end

  def read_json(name)
    JSON.parse(File.read(File.join(out_dir, name)))
  end

  describe "#write_publications" do
    it "writes publications.json verbatim" do
      pubs = [{ "id" => "OIML R 1:2020" }]
      writer.write_publications(pubs)
      expect(read_json("publications.json")).to eq(pubs)
    end
  end

  describe "#write_terms_slim" do
    it "emits slim fields and dedups pubs by (pub_id, clause)" do
      terms = [{
        "slug" => "calibration",
        "name" => "calibration",
        "kind" => "oiml_original",
        "identifier" => "001",
        "editions_present" => ["complete"],
        "designations" => [],
        "alignment" => { "case" => 1, "alignment" => "aligned" },
        "suggested_actions" => [{ "type" => "unique" }],
        "official_concept" => { "id" => "1.1" },
        "publications" => [
          { "publication_id" => "OIML R 1", "clause" => "3.1", "definition" => "def one",
            "tc_sc" => "TC 9", "edition" => "complete" },
          { "publication_id" => "OIML R 1", "clause" => "3.1", "definition" => "def one",
            "tc_sc" => "TC 9", "edition" => "complete" },
          { "publication_id" => "OIML R 2", "clause" => "3.1", "definition" => "def two",
            "tc_sc" => "TC 9", "edition" => "complete" },
        ],
      }]
      writer.write_terms_slim(terms)
      slim = read_json("terms-slim.json")
      expect(slim.size).to eq(1)
      t = slim.first
      expect(t["pub_count"]).to eq(3)  # pub_count counts ALL pubs (not deduped)
      expect(t["distinct_def_count"]).to eq(2)
      expect(t["tc_scs"]).to eq(["TC 9"])
      expect(t["alignment_case"]).to eq(1)
      expect(t["alignment_status"]).to eq("aligned")
      expect(t["action_types"]).to eq(["unique"])
    end
  end

  describe "#write_dashboard" do
    it "computes alignment_counts and priority_terms" do
      terms = [
        { "slug" => "a", "name" => "a", "kind" => "oiml_original",
          "editions_present" => ["complete"],
          "suggested_actions" => [{ "type" => "unique" }],
          "alignment" => { "alignment" => "aligned" },
          "publications" => [{ "publication_id" => "OIML R 1", "definition" => "def" }] },
        { "slug" => "b", "name" => "b", "kind" => "oiml_original",
          "editions_present" => ["complete"],
          "suggested_actions" => [{ "type" => "harmonize" }],
          "alignment" => { "alignment" => "diverges" },
          "publications" => [{ "publication_id" => "OIML R 1", "definition" => "def" }] },
      ]
      pubs = [{ "id" => "OIML R 1", "lifecycle" => "current" }]
      writer.write_dashboard(terms, pubs, [])
      dash = read_json("dashboard.json")
      expect(dash["alignment_counts"]["aligned"]).to eq(1)
      expect(dash["alignment_counts"]["diverges"]).to eq(1)
      expect(dash["concepts_from_current"]).to eq(2)
      expect(dash["pub_current"]).to eq(1)
    end
  end

  describe "#compute_collisions" do
    it "detects raw ID conflicts across terms in the same edition" do
      terms = [{
        "slug" => "test", "name" => "TermA",
        "publications" => [
          { "edition" => "202X", "publication_id" => "OIML R 1",
            "g18_entry" => "00111-R001-1" },
          { "edition" => "202X", "publication_id" => "OIML R 2",
            "g18_entry" => "00111-R002-1" },
        ],
      }, {
        "slug" => "test2", "name" => "TermB",
        "publications" => [
          { "edition" => "202X", "publication_id" => "OIML R 3",
            "g18_entry" => "00111-R003-1" },
        ],
      }]
      result = writer.compute_collisions(terms)
      expect(result[:raw]["202X"]).to_not be_nil
      expect(result[:raw]["202X"].first["id"]).to eq("00111")
    end

    it "detects designation collisions across distinct IDs" do
      terms = [{
        "slug" => "a", "name" => "Same Term",
        "publications" => [
          { "edition" => "202X", "publication_id" => "OIML R 1", "g18_entry" => "00111" },
        ],
      }, {
        "slug" => "b", "name" => "Same Term",
        "publications" => [
          { "edition" => "202X", "publication_id" => "OIML R 2", "g18_entry" => "00222" },
        ],
      }]
      result = writer.compute_collisions(terms)
      expect(result[:designation]["202X"]).to_not be_nil
      expect(result[:designation]["202X"].first["designation"]).to eq("Same Term")
    end
  end

  describe "#write_per_term_detail" do
    it "writes one JSON file per term in web/public/data/terms/" do
      terms = [
        { "slug" => "a", "publications" => [{ "edition" => "x", "definition" => "y" }] },
        { "slug" => "b", "publications" => [] },
      ]
      writer.write_per_term_detail(terms)
      dir = File.join(repo_root, "web", "public", "data", "terms")
      expect(File.exist?(File.join(dir, "a.json"))).to be(true)
      expect(File.exist?(File.join(dir, "b.json"))).to be(true)
      parsed = JSON.parse(File.read(File.join(dir, "a.json")))
      expect(parsed["publications"].first["definition"]).to eq("y")
    end
  end

  describe "#strip_pub" do
    it "removes heavy provenance fields" do
      writer.send(:strip_pub, { "source_lineage" => "x", "definition" => "y" })
        .tap { |r| expect(r).to eq({ "definition" => "y" }) }
    end
  end
end
