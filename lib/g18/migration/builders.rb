# frozen_string_literal: true

# Per-term and per-publication record construction.
#
# These functions take the raw loaded entries (from Loaders) and build the
# YAML records that get written to disk. They delegate designation
# normalization to Normalize and VIM/VIML enrichment to VocabularyEnrichment.

module G18
  module Migration
    module Builders
      module_function

      # Group entries by canonical term key. Returns
      # `{ canonical_downcased => [entries...] }` and mutates `tracking`
      # with annotations_stripped and alias_merges info.
      def group_by_term(entries, aliases:, tracking:)
        groups = Hash.new { |h, k| h[k] = [] }
        variants_seen = Hash.new { |h, k| h[k] = Set.new }
        entries.each do |e|
          raw = Loaders.preferred_designation(e[:concept])
          next unless raw && !raw.empty?
          cleaned = Normalize.normalize_designation(raw)
          tracking[:annotations_stripped][raw] = cleaned if cleaned != raw
          canonical = aliases[cleaned.downcase] || cleaned
          if canonical.downcase != cleaned.downcase
            variants_seen[canonical.downcase] << cleaned
          end
          groups[canonical.downcase] << e
        end
        tracking[:alias_merges] = variants_seen.each_with_object({}) do |(canonical_key, variants), h|
          h[aliases[canonical_key] || canonical_key] = variants.to_a.sort
        end
        groups
      end

      def build_publication_entry(entry, bib)
        concept = entry[:concept]
        raw     = entry[:raw]
        src_id = Loaders.source_ref(concept)
        bib_e  = bib[src_id]
        edges  = Loaders.see_edges(concept)
        adoption = Loaders.adoption_info(concept, raw: raw)
        lineage  = Loaders.source_lineage(concept, raw: raw)
        pub = {
          "edition"            => entry[:edition],
          "publication"        => (bib_e && bib_e["reference"]) || src_id,
          "publication_id"     => src_id,
          "tc_sc"              => (bib_e && bib_e["tc_sc"]) || "",
          "year"               => (bib_e && Loaders.parse_year(bib_e["id"])) || Loaders.parse_year(src_id),
          "clause"             => Loaders.clause_ref(concept, raw: raw),
          "link"               => (bib_e && bib_e["link"]),
          "g18_entry"          => Loaders.identifier(concept),
          "definition"         => Loaders.definition_text(concept),
          "definition_paragraphs" => Loaders.definition_paragraphs(concept, raw: raw),
          "notes"              => Loaders.notes_text(concept),
          "note_paragraphs"    => Loaders.note_paragraphs(concept, raw: raw),
          "examples"           => Loaders.examples_text(concept),
          "example_paragraphs" => Loaders.example_paragraphs(concept, raw: raw),
          "source"             => adoption,
          "source_lineage"     => lineage,
          "consistency"        => "pending",
          "consistency_reason" => "",
        }
        # Preserve each instance's own see-edges on the publication entry, so
        # the total count of `publications[*].related` across the dataset equals
        # the number of source instances that asserted an edge. The term-level
        # `related` block in `build_term_record` is the deduped superset.
        pub["related"] = edges.map { |e| { "type" => "see", "ref" => e["ref"] } } unless edges.empty?
        pub
      end

      def merged_edges(instances)
        instances
          .sort_by { |e| Loaders.identifier(e[:concept]).to_s }
          .flat_map { |e| Loaders.see_edges(e[:concept]) }
          .uniq { |edge| [edge.dig("ref", "source"), edge.dig("ref", "id")] }
      end

      def pick_official(edges)
        return ["oiml_original", nil] if edges.empty?
        edge = edges.first
        ref = edge["ref"] || {}
        urn = ref["source"]
        id = ref["id"]
        [
          VocabularyEnrichment.kind_for_urn(urn),
          { "source" => urn, "id" => id, "url" => VocabularyEnrichment.vocab_concept_url(urn, id) },
        ]
      end

      # Merge all designations across instances, deduping by [type, status, text].
      # Output ordering: preferred expression first, then admitted expressions,
      # then symbols (preferred first), then abbreviations.
      def merge_designations(instances)
        seen = {}
        out = []
        instances.each do |e|
          Loaders.all_designations(e[:concept]).each do |d|
            key = [d["type"], d["status"], d["text"]]
            next if seen[key]
            seen[key] = true
            out << d
          end
        end
        # Order: preferred-expression, admitted-expression, preferred-symbol,
        # admitted-symbol, abbreviation, anything else.
        rank = {
          ["expression", "preferred"] => 0,
          ["expression", "admitted"]  => 1,
          ["symbol",     "preferred"] => 2,
          ["symbol",     "admitted"]  => 3,
          ["abbreviation", "preferred"] => 4,
          ["abbreviation", "admitted"]  => 5,
        }
        out.sort_by { |d| [rank[[d["type"], d["status"]]] || 9, d["text"].downcase] }
      end

      def build_term_record(term_key, instances, bib, aliases:, vocab_dir: nil, primary_edition: nil)
        # Sort: primary edition first, then prefer pure-numeric G 18 entry
        # numbers (like "02900") over compound IDs derived from vocabulary
        # sources (like "02251-D011"), then by identifier value.
        sorted = instances.sort_by do |e|
          edition_rank = e[:edition] == primary_edition ? 0 : 1
          id = Loaders.identifier(e[:concept]).to_s
          id_is_numeric = id.match?(/\A\d+\z/) ? 0 : 1
          [edition_rank, id_is_numeric, id]
        end
        first = sorted.first
        edges = merged_edges(sorted)
        kind, official = pick_official(edges)
        pubs = sorted
          .map { |e| build_publication_entry(e, bib) }
          .sort_by { |p| [p["edition"].to_s, -(p["year"] || 0), p["publication_id"].to_s, p["clause"].to_s] }

        # Display name: prefer the alias canonical (preserves exact casing
        # from the aliases file); otherwise use the first instance's cleaned
        # designation.
        display_name = aliases[term_key] || Normalize.normalize_designation(Loaders.preferred_designation(first[:concept]) || term_key)

        # Enrich the official concept with VIM/VIML metadata + authoritative
        # definition text so term pages render the baseline without a fetch.
        if official && vocab_dir
          official = VocabularyEnrichment.enrich_authority_ref(vocab_dir, official)
        end

        enriched_edges = edges.map do |edge|
          next edge unless vocab_dir && edge.is_a?(Hash)
          ref = edge["ref"]
          next edge unless ref
          edge.merge("ref" => VocabularyEnrichment.enrich_authority_ref(vocab_dir, ref))
        end

        editions_present = instances.map { |e| e[:edition] }.compact.uniq.sort

        # Merge all designations across instances (dedupe by type+status+text).
        # The display name (`term` field) stays as the first preferred expression
        # for backward compat; `designations` is the full set for the UI to render
        # preferred / admitted / symbol blocks.
        merged_designations = merge_designations(instances)

        {
          "data" => {
            "identifier"       => Loaders.identifier(first[:concept]),
            "term"             => display_name,
            "designations"     => merged_designations,
            "kind"             => kind,
            "official_concept" => official,
            "editions_present" => editions_present,
            "primary_edition"  => primary_edition,
            "publications"     => pubs,
          },
          "status"         => "current",
          "id"             => Loaders.deterministic_uuid(term_key),
          "schema_version" => "3",
          "related"        => enriched_edges.map { |e| { "type" => e["type"], "ref" => e["ref"] } },
        }
      end
    end
  end
end
