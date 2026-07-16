# frozen_string_literal: true

require "fileutils"

require_relative "../vocabulary"
require_relative "../migration/conflicts"
require_relative "publication_enricher"
require_relative "glossarist_bridge"
require_relative "concept_differ"
require_relative "term_processor"
require_relative "sourced_from_enricher"
require_relative "json_writer"
require_relative "latest_datasets"

module G18
  module Export
    # Orchestrates the full export pipeline. Constructed with options and
    # invoked via #call, which returns a stats hash. Side-effect: writes
    # all JSON output to disk.
    #
    # Responsibilities:
    #   1. Load latest V1/V2 indices (via glossarist-js bridge)
    #   2. Compute concept diffs (historic ↔ latest)
    #   3. Enrich publications from relaton (TC/SC, lifecycle)
    #   4. Process each term YAML into enriched term hashes
    #   5. Enrich publication instances with sourced_from
    #   6. Write every JSON output file
    class Pipeline
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def call
        FileUtils.mkdir_p(options[:out_dir])
        script_dir = File.join(repo_root, "web", "scripts")
        vocab_root = options[:vocab_root]
        relaton_root = ENV.fetch("RELATON_ROOT",
          File.expand_path("../../relaton/relaton-data-oiml", repo_root))

        bridge = GlossaristBridge.new(script_dir: script_dir, vocab_root: vocab_root)
        latest_indices, latest_full = load_latest_indices(bridge, vocab_root)
        concept_diffs = ConceptDiffer.new(script_dir: script_dir, vocab_root: vocab_root).call
        enrichment = PublicationEnricher.new(vocab_root: vocab_root, relaton_root: relaton_root).call

        result = TermProcessor.new(
          glossarist_bridge: bridge,
          latest_indices: latest_indices,
          latest_full_concepts: latest_full,
          concept_diffs: concept_diffs,
          publication_enrichment: enrichment,
        ).call(options[:data_dir])

        SourcedFromEnricher.new(vocab_root: vocab_root).call(result.terms)

        writer = JsonWriter.new(out_dir: options[:out_dir], repo_root: repo_root)
        collisions = writer.compute_collisions(result.terms)
        writer.call(
          terms: result.terms,
          publications: enrichment.publications,
          vocab_gaps: result.vocab_gaps,
          raw_conflicts: collisions[:raw],
        )

        print_summary(result, enrichment, collisions)
        { terms: result.terms.size, publications: enrichment.publications.size }
      end

      private

      def repo_root
        # lib/g18/export/pipeline.rb → lib/g18/export → lib/g18 → lib → repo_root
        @repo_root ||= File.expand_path("../../..", __dir__)
      end

      def load_latest_indices(bridge, vocab_root)
        indices = {}
        full = {}
        LatestDatasets.each do |vocab, info|
          concepts_dir = File.join(vocab_root, info[:dir], "concepts")
          if Dir.exist?(concepts_dir)
            idx, f = bridge.load_index(concepts_dir)
            indices[vocab] = idx
            full[vocab] = f
            warn "  Latest #{info[:label]}: #{idx.size} designations indexed (via glossarist-js)"
          else
            warn "  Latest #{info[:label]}: concepts dir not found at #{concepts_dir} — latest_check will be skipped"
          end
        end
        [indices, full]
      end

      def print_summary(result, enrichment, collisions)
        puts "Exported for Vite:"
        puts "  Publications:        #{enrichment.publications.size}"
        puts "  Terms:               #{result.terms.size}"
        puts "  Vocabulary gaps:     #{result.vocab_gaps.size}"
        puts "  Raw conflicts:       #{collisions[:raw].values.sum(&:size)}"
        puts "  Designation coll:    #{collisions[:designation].values.sum(&:size)}"
        puts "  Output: #{options[:out_dir]}/"
      end
    end
  end
end
