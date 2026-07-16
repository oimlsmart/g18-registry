# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require_relative "../../lib/g18/export"

RSpec.describe G18::Export::Pipeline, "#call" do
  VOCAB_ROOT = File.expand_path("../../../vocab/datasets", __dir__)
  REPO_ROOT  = File.expand_path("../..", __dir__)

  # Run the pipeline ONCE for the whole "with real vocab checkout" group.
  # The pipeline takes ~1 minute (loads 2913 YAML files + glossarist-js
  # for every vocab dataset). Running it per-test would be untenable.
  def self.requires_vocab!
    before(:all) do
      skip "vocab repo not at #{VOCAB_ROOT}" unless Dir.exist?(File.join(VOCAB_ROOT, "oiml-complete", "concepts"))
    end
  end

  # Shared state — run pipeline once for all tests in this group.
  shared_context "pipeline run" do
    before(:all) do
      @out_dir = Dir.mktmpdir("pipeline-out")
      @web_public_data = Dir.mktmpdir("pipeline-public")
      @options = {
        data_dir: File.join(REPO_ROOT, "data"),
        out_dir: @out_dir,
        vocab_root: VOCAB_ROOT,
        # Redirect per-entity output to tmpdir, but keep script_dir pointing
        # at the real web/scripts so Node.js modules resolve correctly.
        script_dir: File.join(REPO_ROOT, "web", "scripts"),
        repo_root: @web_public_data,
      }
      pipeline = G18::Export::Pipeline.new(@options)
      @stats = pipeline.call
    end

    after(:all) do
      FileUtils.remove_entry(@out_dir) if @out_dir && File.exist?(@out_dir)
      FileUtils.remove_entry(@web_public_data) if @web_public_data && File.exist?(@web_public_data)
    end

    def read_json(name)
      JSON.parse(File.read(File.join(@out_dir, name)))
    end
  end

  describe "with real vocab checkout", :requires_vocab do
    requires_vocab!
    include_context "pipeline run"

    it "writes every expected JSON output file" do
      expected = %w[
        publications.json terms.json terms-slim.json terms-medium.json
        dashboard.json tc.json tc-stats.json edition-stats.json
        harmonization.json harmonization-slim.json conflicts.json
        vocab-gaps.json actions-data.json g18-dynamic.json
        readiness-stats.json leaderboard-data.json pub-list.json
      ]
      expected.each do |f|
        path = File.join(@out_dir, f)
        expect(File.exist?(path)).to be(true), "expected #{path} to exist"
      end
    end

    it "produces dashboard.json with required top-level keys" do
      dash = read_json("dashboard.json")
      expect(dash["total_terms"]).to be > 0
      expect(dash["total_publications"]).to be > 0
      expect(dash["alignment_counts"]).to be_a(Hash)
      expect(dash["kind_counts"]).to be_a(Hash)
      expect(dash["pub_current"]).to be_a(Integer)
      expect(dash["pub_retired"]).to be_a(Integer)
      expect(dash["pub_withdrawn"]).to be_a(Integer)
    end

    it "alignment_counts keys match the 4 implemented cases" do
      # Case 2 (historic) not yet implemented
      counts = read_json("dashboard.json")["alignment_counts"]
      expect(counts.keys).to include("aligned", "diverges", "fuzzy", "none")
    end

    it "terms-slim.json entries have the documented slim fields" do
      sample = read_json("terms-slim.json").first
      expect(sample).to include(
        "slug", "name", "kind", "identifier",
        "editions_present", "pub_count", "pub_ids",
        "tc_scs", "tc_counts", "distinct_def_count",
        "action_types", "designations",
      )
    end

    it "writes per-term detail JSON for every slug" do
      slim = read_json("terms-slim.json")
      sample_slug = slim.first["slug"]
      path = File.join(@web_public_data, "web", "public", "data", "terms", "#{sample_slug}.json")
      expect(File.exist?(path)).to be(true)
      detail = JSON.parse(File.read(path))
      expect(detail["slug"]).to eq(sample_slug)
    end

    it "writes per-publication detail JSON for every publication" do
      pubs = read_json("publications.json")
      sample_id = pubs.first["id"]
      slug = sample_id.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      path = File.join(@web_public_data, "web", "public", "data", "publications", "#{slug}.json")
      expect(File.exist?(path)).to be(true)
    end

    it "conflicts.json has both raw and designation_collisions keys" do
      c = read_json("conflicts.json")
      expect(c).to include("raw", "designation_collisions")
      expect(c["raw"]).to be_a(Hash)
      expect(c["designation_collisions"]).to be_a(Hash)
    end

    it "vocab-gaps.json entries have near_misses + slug + name" do
      gaps = read_json("vocab-gaps.json")
      expect(gaps.length).to be > 0
      sample = gaps.first
      expect(sample).to include("slug", "name", "near_misses")
      expect(sample["near_misses"]).to include("vim", "viml")
    end

    it "returns a stats hash with terms + publications counts" do
      expect(@stats).to include(:terms, :publications)
      expect(@stats[:terms]).to be > 0
      expect(@stats[:publications]).to be > 0
    end
  end

  describe "with missing vocab dir" do
    it "still produces dashboard.json with empty alignment_counts" do
      empty_data = Dir.mktmpdir("empty-data")
      empty_vocab = Dir.mktmpdir("empty-vocab")
      alt_out = Dir.mktmpdir("alt-out")
      alt_public = Dir.mktmpdir("alt-public")
      pipeline = described_class.new(
        data_dir: empty_data,
        out_dir: alt_out,
        vocab_root: empty_vocab,
        script_dir: File.join(REPO_ROOT, "web", "scripts"),
        repo_root: alt_public,
      )
      pipeline.call

      dash = JSON.parse(File.read(File.join(alt_out, "dashboard.json")))
      expect(dash["total_terms"]).to eq(0)
      expect(dash["alignment_counts"]).to eq({})
    ensure
      [empty_data, empty_vocab, alt_out, alt_public].each do |d|
        FileUtils.remove_entry(d) if d && File.exist?(d)
      end
    end
  end
end
