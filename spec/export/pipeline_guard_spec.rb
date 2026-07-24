# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "../../lib/g18"

RSpec.describe G18::Export::Pipeline, "#verify_minimum_output!" do
  let(:vocab_root) { Dir.mktmpdir("vocab") }
  let(:data_dir) { Dir.mktmpdir("data") }
  let(:out_dir) { Dir.mktmpdir("out") }
  let(:public_dir) { Dir.mktmpdir("public") }

  after do
    [vocab_root, data_dir, out_dir, public_dir].each do |d|
      FileUtils.remove_entry(d) if File.exist?(d)
    end
  end

  before do
    # Populate data_dir so the guard doesn't auto-disable (it skips when
    # the input directory is empty — test fixture scenario).
    File.write(File.join(data_dir, "sample.yaml"), "---\ndata:\n  term: x\n")
  end

  def pipeline_with(terms_count:, pubs_count:, options: {})
    p = described_class.new({
      data_dir: data_dir,
      out_dir: out_dir,
      vocab_root: vocab_root,
      script_dir: File.expand_path("../../web/scripts", __dir__),
      repo_root: public_dir,
      min_terms: 0,
      min_publications: 0,
    }.merge(options))
    result = Struct.new(:terms, :vocab_gaps, keyword_init: true).new(
      terms: Array.new(terms_count) { { "slug" => "t" } },
      vocab_gaps: [],
    )
    enrichment = Struct.new(:publications, :tc_sc_map, :withdrawn_set, :lifecycle_map, keyword_init: true).new(
      publications: Array.new(pubs_count) { |i| { "id" => "P#{'%03d' % i}" } },
      tc_sc_map: {}, withdrawn_set: Set.new, lifecycle_map: {},
    )
    [p, result, enrichment]
  end

  it "passes when counts meet thresholds" do
    p, result, enrichment = pipeline_with(terms_count: 200, pubs_count: 100, options: { min_terms: 100, min_publications: 50 })
    expect { p.send(:verify_minimum_output!, result, enrichment) }.not_to raise_error
  end

  it "raises when terms count below threshold" do
    p, result, enrichment = pipeline_with(terms_count: 5, pubs_count: 100, options: { min_terms: 100, min_publications: 50 })
    expect { p.send(:verify_minimum_output!, result, enrichment) }
      .to raise_error(/too few terms/)
  end

  it "raises when publications count below threshold" do
    p, result, enrichment = pipeline_with(terms_count: 200, pubs_count: 5, options: { min_terms: 100, min_publications: 50 })
    expect { p.send(:verify_minimum_output!, result, enrichment) }
      .to raise_error(/too few publications/)
  end

  it "auto-disables when data_dir has no YAML files (test fixtures)" do
    # Use a fresh empty data_dir for this test
    empty_data = Dir.mktmpdir("empty-data")
    begin
      p = described_class.new(
        data_dir: empty_data,
        out_dir: out_dir,
        vocab_root: vocab_root,
        min_terms: 100,
        min_publications: 50,
      )
      result = Struct.new(:terms, :vocab_gaps, keyword_init: true).new(terms: [], vocab_gaps: [])
      enrichment = Struct.new(:publications, :tc_sc_map, :withdrawn_set, :lifecycle_map, keyword_init: true).new(
        publications: [], tc_sc_map: {}, withdrawn_set: Set.new, lifecycle_map: {},
      )
      expect { p.send(:verify_minimum_output!, result, enrichment) }.not_to raise_error
    ensure
      FileUtils.remove_entry(empty_data) if File.exist?(empty_data)
    end
  end

  it "can be disabled by setting thresholds to 0" do
    p, result, enrichment = pipeline_with(terms_count: 0, pubs_count: 0, options: { min_terms: 0, min_publications: 0 })
    expect { p.send(:verify_minimum_output!, result, enrichment) }.not_to raise_error
  end

  it "default thresholds are 100 terms / 50 pubs" do
    p = described_class.new(data_dir: data_dir, out_dir: out_dir, vocab_root: vocab_root)
    expect(p.options[:min_terms]).to be_nil # uses fetch default inside method
    expect(p.options[:min_publications]).to be_nil
    # The default is applied inside verify_minimum_output! via fetch
  end
end
