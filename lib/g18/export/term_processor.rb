# frozen_string_literal: true

require "yaml"
require "set"

require_relative "../vocabulary"
require_relative "../actions"
require_relative "../fuzzy_match"
require_relative "renderer"
require_relative "matcher"
require_relative "data_fixups"
require_relative "latest_datasets"

module G18
  module Export
    # Processes each per-term YAML file under data/ into a fully enriched
    # term hash ready for JSON output. One pass, no I/O beyond reading the
    # YAML files.
    #
    # Responsibilities per term:
    #   - propagate tc_sc / withdrawn / lifecycle from enriched publications
    #   - apply documented data fixups
    #   - classify alignment against V1/V2 (5-case)
    #   - check latest-edition presence + canonical mismatch
    #   - load cited + latest authoritative concept via glossarist bridge
    #   - compile suggested actions via Actions::Compiler
    #   - render stem:[...] markup
    #
    # Also collects vocab-gap rows for OIML-original terms along the way
    # (avoids a second pass over the same files).
    class TermProcessor
      Result = Struct.new(:terms, :vocab_gaps, keyword_init: true)

      def initialize(glossarist_bridge:, latest_indices:, latest_full_concepts:, concept_diffs:, publication_enrichment:)
        @glossarist = glossarist_bridge
        @latest_indices = latest_indices
        @latest_full_concepts = latest_full_concepts
        @concept_diffs = concept_diffs
        @enrichment = publication_enrichment
      end

      def call(data_dir)
        terms = []
        vocab_gaps = []
        Dir.glob(File.join(data_dir, "*.yaml")).sort.each do |path|
          record = process_file(path)
          next unless record
          terms << record[:term]
          vocab_gaps << record[:gap] if record[:gap]
        end
        Result.new(terms: terms, vocab_gaps: vocab_gaps)
      end

      private

      def process_file(path)
        docs = YAML.safe_load_stream(File.read(path), aliases: true)
        return nil unless docs.first.is_a?(Hash)
        hash = docs.find { |d| d.is_a?(Hash) && d["data"] && d["data"]["term"] } || docs.first
        data = hash["data"] || {}
        slug = File.basename(path, ".yaml")

        propagate_publication_fields(data)
        apply_data_fixups(data)

        is_oiml_original = oiml_specific?(data["kind"])
        first_def = first_definition(data["publications"])
        alignment_result = data["term"] ?
          Matcher.classify_alignment(data["term"], first_def, @latest_indices, @latest_full_concepts, LatestDatasets.to_h) : nil
        vocab_presence = is_oiml_original ?
          { "vim" => alignment_result&.dig("vim"), "viml" => alignment_result&.dig("viml") } : nil
        alignment = alignment_result&.slice("case", "alignment", "matched_vocab")

        gap = collect_vocab_gap(slug, data, vocab_presence) if is_oiml_original && data["term"]

        latest = compute_latest_check(data)
        canonical_mismatch = compute_canonical_mismatch(data, latest)
        cited_concept, latest_concept, cited_dir, vocab_sym = load_authoritative_concepts(data, latest)
        full_concept = latest_concept || cited_concept
        concept_diff = lookup_concept_diff(data, cited_dir, vocab_sym)

        term = build_term_hash(
          slug: slug, data: data, hash: hash,
          latest: latest, vocab_presence: vocab_presence, alignment: alignment,
          canonical_mismatch: canonical_mismatch,
          full_concept: full_concept, cited_concept: cited_concept, latest_concept: latest_concept,
          concept_diff: concept_diff,
        )
        { term: term, gap: gap }
      rescue StandardError => e
        warn "  WARNING: failed to process #{path}: #{e.message}"
        nil
      end

      def oiml_specific?(kind)
        kind == "oiml_original" || kind == "undefined"
      end

      def first_definition(pubs)
        (pubs || []).map { |p| p["definition"] }.compact.first
      end

      def propagate_publication_fields(data)
        pubs = data["publications"] || []
        pubs.each do |p|
          propagate_tc_sc(p)
          propagate_lifecycle(p)
        end
      end

      def propagate_tc_sc(p)
        return if p["tc_sc"] && !p["tc_sc"].to_s.strip.empty?
        return unless p["publication_id"]
          tc = @enrichment.tc_sc_map[p["publication_id"]]
        p["tc_sc"] = tc if tc
      end

      def propagate_lifecycle(p)
        p["withdrawn"] = true if @enrichment.withdrawn_set.include?(p["publication_id"])
        lc = @enrichment.lifecycle_map[p["publication_id"]]
        p["lifecycle"] = lc if lc
      end

      def apply_data_fixups(data)
        (data["publications"] || []).each { |p| DataFixups.apply_to_publication!(p) }
        drop_complete_edition!(data)
      end

      # Drop ALL publication instances sourced from oiml-complete (edition="complete").
      #
      # oiml-complete is the live concept registry — a superset of all G 18
      # concepts. Its concept identifiers encode a pub-slug-seq format
      # (e.g. r99-1-2-2008-25) that produces garbage when decoded as a
      # publication reference:
      #
      #   - publication_id: "OIML R 99-1-2:2008" (doesn't exist — real pub
      #     is OIML R 99-1:2008, not R 99-1-2)
      #   - clause: "25" (the sequence number, not a real clause)
      #   - g18_entry: "r99-1-2-2008-25" (compound slug, not a G 18 entry)
      #
      # Real G 18 instances (202X / 2010) have correct publication IDs,
      # clause references, and numeric G 18 entry numbers. Dropping all
      # 'complete' instances ensures the concept detail page only shows
      # real publication references.
      #
      # Terms that ONLY had complete instances (not yet in any G 18 edition)
      # will show zero publication instances on their detail page — which is
      # accurate: they exist in the concept registry but aren't cited by any
      # G 18 edition yet.
      def drop_complete_edition!(data)
        pubs = data["publications"] || []
        return if pubs.empty?
        data["publications"] = pubs.reject { |p| p["edition"].to_s == "complete" }
        # Also strip 'complete' from editions_present — it's no longer a
        # real G 18 edition after dropping the instances.
        eds = data["editions_present"]
        data["editions_present"] = eds - ["complete"] if eds.is_a?(Array)
      end

      def collect_vocab_gap(slug, data, vocab_presence)
        pubs = data["publications"] || []
        gap_pubs = pubs.map { |p| { "publication_id" => p["publication_id"], "tc_sc" => p["tc_sc"], "edition" => p["edition"] } }
        gap_defs = pubs.map { |p| p["definition"] }.compact.uniq
        {
          "slug" => slug,
          "name" => Renderer.render_stem(data["term"]),
          "identifier" => data["identifier"],
          "definitions" => gap_defs,
          "publications" => gap_pubs,
          "editions_present" => data["editions_present"],
          "near_misses" => vocab_presence || { "vim" => nil, "viml" => nil },
        }
      end

      def compute_latest_check(data)
        oc_urn = data["official_concept"]&.dig("source")
        oc_id = data["official_concept"]&.dig("id")
        return nil unless oc_urn
        Matcher.check_latest_edition(data["term"], oc_urn, oc_id, @latest_indices, LatestDatasets.to_h)
      end

      def compute_canonical_mismatch(data, latest)
        return nil unless latest && !latest["found"]
        oc_urn = data["official_concept"]&.dig("source")
        v = G18::Vocabulary.vocab(oc_urn)
        return nil unless v && @latest_indices[v]&.any?
        m = G18::FuzzyMatch.match(data["term"], @latest_indices[v])
        return nil unless m
        info = LatestDatasets[v]
        {
          "vocab" => v.to_s,
          "latest_label" => info[:label],
          "designation" => m[:designation],
          "concept_id" => m[:entry][:id],
          "similarity" => m[:similarity].round(3),
        }
      end

      def load_authoritative_concepts(data, latest)
        oc = data["official_concept"]
        return [nil, nil, nil, nil] unless oc && oc["id"]
        oc_urn = oc["source"]
        v = G18::Vocabulary.vocab(oc_urn)
        cited_dir = derive_cited_dir(oc_urn)
        cited_concept = cited_dir ? @glossarist.lookup_concept(cited_dir, oc["id"]) : nil
        latest_concept = resolve_latest_concept(v, oc["id"], latest)
        [cited_concept, latest_concept, cited_dir, v]
      end

      def derive_cited_dir(oc_urn)
        return nil unless oc_urn
        oc_urn.match(/v:[12]:(\d{4})/) do |m|
          year = m[1]
          vocab_prefix = oc_urn.include?("v:2") ? "vim" : "viml"
          "#{vocab_prefix}-#{year}"
        end
      end

      def resolve_latest_concept(vocab, oc_id, latest)
        return nil unless vocab
        info = LatestDatasets[vocab]
        return nil unless info
        latest_id = (latest && latest["found"]) ? latest["concept_id"] : oc_id
        (@latest_full_concepts[vocab] || {})[latest_id]
      end

      def lookup_concept_diff(data, cited_dir, vocab)
        return nil unless cited_dir && vocab
        info = LatestDatasets[vocab]
        return nil unless info
        oc_id = data["official_concept"]&.dig("id")
        return nil unless oc_id
        diff_key = "#{cited_dir}->#{info[:dir]}"
        @concept_diffs[diff_key]&.dig(oc_id.to_s)
      end

      def build_term_hash(slug:, data:, hash:, latest:, vocab_presence:, alignment:, canonical_mismatch:, full_concept:, cited_concept:, latest_concept:, concept_diff:)
        kind = data["kind"]
        {
          "slug" => slug,
          "identifier" => data["identifier"],
          "name" => Renderer.render_stem(data["term"]),
          "designations" => Renderer.render_stem_deep(data["designations"] || []),
          "kind" => kind,
          "official_concept" => Renderer.render_stem_deep(data["official_concept"])&.merge(
            "full_concept" => Renderer.render_stem_deep(full_concept),
            "cited_concept" => Renderer.render_stem_deep(cited_concept),
            "latest_concept" => Renderer.render_stem_deep(latest_concept),
            "concept_diff" => concept_diff,
          ),
          "editions_present" => data["editions_present"],
          "primary_edition" => data["primary_edition"],
          "latest_check" => latest,
          "suggested_actions" => G18::Actions::Compiler.for_term(
            "data" => data, "latest_check" => latest,
            "vocab_presence" => vocab_presence,
            "canonical_mismatch" => canonical_mismatch,
            "alignment" => alignment,
          ).map(&:to_h),
          "publications" => (data["publications"] || []).map do |p|
            Renderer.render_stem_deep(p).merge(
              "defined" => kind == "defined_in_vim" || kind == "defined_in_viml",
              "official_concept" => Renderer.render_stem_deep(data["official_concept"]),
              "primary_edition" => data["primary_edition"],
            )
          end,
          "related" => Renderer.render_stem_deep(hash["related"] || []),
          "vocab_presence" => vocab_presence,
          "alignment" => alignment,
        }
      end
    end
  end
end
