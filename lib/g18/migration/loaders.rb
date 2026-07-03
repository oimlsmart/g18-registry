# frozen_string_literal: true

# Concept loading + field extraction.
#
# Consumes Glossarist::V3::ManagedConcept objects (the typed model
# for the vocab repo's v3 schema). Files are parsed once via
# Glossarist::V3::ConceptDocument.from_yamls and the ManagedConcept is
# stored on the entry. All downstream access uses typed method calls
# rather than raw Hash#dig chains.

require "glossarist" unless defined?(Glossarist)

module G18
  module Migration
    module Loaders
      module_function

      # A v3 concept file is multi-doc YAML (Concept metadata + LocalizedConcept).
      # Glossarist's V3::ConceptDocument handles the round-trip; we expose the
      # resulting ManagedConcept.
      # A v3 concept file is multi-doc YAML (Concept metadata + LocalizedConcept).
      # Glossarist's V3::ConceptDocument handles the round-trip; we expose the
      # resulting ManagedConcept. The raw YAML docs are kept alongside as
      # `:raw` for fields that glossarist V3 doesn't surface (e.g. source
      # locality — the V3::Citation adapter only persists `ref`, dropping the
      # clause reference).
      def load_concept_file(file, edition: nil)
        raw = File.read(file, encoding: "utf-8")
        docs = YAML.safe_load_stream(raw, filename: file, aliases: true)
        doc = Glossarist::V3::ConceptDocument.from_yamls(raw)
        { file: file, concept: doc.to_managed_concept, raw: docs, edition: edition }
      end

      def load_concept_dir(dir, edition: nil)
        Dir.glob(File.join(dir, "*.yaml")).sort.map do |file|
          load_concept_file(file, edition: edition)
        end
      end

      def load_bibliography(path)
        entries = YAML.safe_load(File.read(path), aliases: true) || []
        entries = entries.is_a?(Array) ? entries : [entries]
        entries.each_with_object({}) { |e, h| h[e["id"]] = e if e.is_a?(Hash) }
      end

      # ── Field accessors (take a ManagedConcept) ────────────────────────

      def identifier(concept)
        concept&.data&.id
      end

      # English localization. vocab datasets are eng-only at present.
      def eng_localization(concept)
        concept.localizations.find { |l| l.data.language_code == "eng" } ||
          concept.localizations.first
      end

      def preferred_designation(concept)
        loc = eng_localization(concept)
        return nil unless loc
        terms = loc.data.terms
        return nil unless terms && !terms.empty?
        pref = terms.find { |t| preferred?(t) && expression?(t) }
        pref ||= terms.find { |t| preferred?(t) }
        pref ||= terms.first
        pref&.designation
      end

      # All designations on the English localization, normalised to a uniform
      # Hash shape for serialization. Returns [] when there are no terms.
      def all_designations(concept)
        loc = eng_localization(concept)
        return [] unless loc
        terms = loc.data.terms
        return [] unless terms.is_a?(Array)
        terms.map do |t|
          next nil unless t.respond_to?(:designation) && t.designation
          {
            "type"          => designation_type(t),
            "status"        => designation_status(t),
            "text"          => Normalize.normalize_designation(t.designation),
            "usage_info"    => designation_usage_info(t),
            "field"         => designation_field(t),
            "international" => designation_international?(t),
          }
        end.compact
      end

      def definition_text(concept)
        loc = eng_localization(concept)
        return "" unless loc
        defs = loc.data.definition
        return "" unless defs
        defs.map { |d| d.respond_to?(:content) ? d.content : nil }.compact.join("\n")
      end

      def notes_text(concept)
        loc = eng_localization(concept)
        return [] unless loc
        notes = loc.data.notes
        return [] unless notes
        notes.map { |n| n.respond_to?(:content) ? n.content : nil }.compact
      end

      def examples_text(concept)
        loc = eng_localization(concept)
        return [] unless loc
        examples = loc.data.examples
        return [] unless examples
        examples.map { |x| x.respond_to?(:content) ? x.content : nil }.compact
      end

      # Related concepts of type "see" (VIM/VIML authoritative citations).
      # Surfaces them in the same shape the rest of the pipeline already
      # expects: `{"type" => "see", "ref" => {"source" => urn, "id" => id}}`.
      def see_edges(concept)
        related = concept.related || concept.data&.related
        return [] unless related.is_a?(Array)
        related.select { |r| r.respond_to?(:type) && Array(r.type).include?("see") }.map do |r|
          ref = r.respond_to?(:ref) ? r.ref : nil
          {
            "type" => "see",
            "ref"  => {
              "source" => ref&.respond_to?(:source) ? ref.source : ref&.dig("source"),
              "id"     => ref&.respond_to?(:id)     ? ref.id     : ref&.dig("id"),
            },
          }
        end
      end

      # First source's publication ID (e.g. "OIML R111-1:2004").
      def source_ref(concept)
        src = concept.data&.sources&.first
        return nil unless src
        ref = src.respond_to?(:origin) ? src.origin&.ref : nil
        ref&.source
      end

      # First source's clause (e.g. "T.3.3"). Glossarist V3::Citation drops the
      # locality on parse, so fall back to the raw YAML.
      def clause_ref(concept, raw: nil)
        if raw
          doc = raw.find { |d| d.is_a?(Hash) && d["data"] && d.dig("data", "sources") }
          value = doc&.dig("data", "sources", 0, "locality", "reference_from")
          return value unless value.nil?
        end
        src = concept.data&.sources&.first
        return nil unless src
        origin = src.respond_to?(:origin) ? src.origin : nil
        loc = origin&.locality if origin
        return nil unless loc
        loc.respond_to?(:reference_from) ? loc.reference_from : nil
      end

      def parse_year(s)
        m = s.to_s.match(/:(\d{4})\z/)
        m && m[1].to_i
      end

      def slugify(term)
        G18::Model::Identifier.slugify(term)
      end

      def deterministic_uuid(name)
        G18::Model::Identifier.deterministic_uuid(name)
      end

      # ── helpers ────────────────────────────────────────────────────────

      def preferred?(term)
        statuses = term.respond_to?(:normative_status) ? Array(term.normative_status) : []
        statuses.include?("preferred")
      end

      def expression?(term)
        term.is_a?(Glossarist::Designation::Expression)
      end

      # Glossarist maps each term to a Designation subclass; surface its name
      # in the schema's vocabulary: expression / symbol / abbreviation.
      def designation_type(term)
        case term.class.name
        when /ExpressionDesignation\z/, /Designation::Expression\z/ then "expression"
        when /SymbolDesignation\z/,    /Designation::Symbol\z/     then "symbol"
        when /AbbreviationDesignation\z/, /Designation::Abbreviation\z/ then "abbreviation"
        when /LetterSymbolDesignation\z/ then "letter_symbol"
        when /GraphicalSymbolDesignation\z/ then "graphical_symbol"
        else (term.respond_to?(:type) ? Array(term.type).first : "expression") || "expression"
        end
      end

      def designation_status(term)
        statuses = term.respond_to?(:normative_status) ? Array(term.normative_status) : []
        statuses.first || "preferred"
      end

      # `usage_info` and `field_of_application` disambiguate homonymous
      # designations: e.g. "error (of indication)" vs "error (of measurement)"
      # share the bare word "error" but carry different usage_info. Two
      # designations with the same text but different usage_info are
      # DIFFERENT concepts — the most dangerous dedup trap for TC1.
      def designation_usage_info(term)
        val = term.respond_to?(:usage_info) ? term.usage_info : nil
        val = nil if val.respond_to?(:empty?) && val.empty?
        val
      end

      def designation_field(term)
        val = term.respond_to?(:field_of_application) ? term.field_of_application : nil
        val = nil if val.respond_to?(:empty?) && val.empty?
        val
      end

      # `international: true` on a SymbolDesignation marks a globally
      # recognized symbol (ISO/VIM convention) vs an OIML-coined one.
      def designation_international?(term)
        return false unless term.respond_to?(:international)
        !!term.international
      end

      # Adoption provenance: did this concept's definition come straight
      # from a VIM/VIML/OIML document, and if so was it verbatim or modified?
      # Glossarist stores this on ConceptSource#status ("identical"/"modified")
      # plus an optional `modification` text describing what changed.
      #
      # Inspects BOTH the managed concept's sources and the localized
      # concept's sources, since vocab data is inconsistent about where
      # the adoption source lives. Glossarist V3 drops localized sources
      # on parse (similar to the locality bug), so fall back to the raw
      # YAML for those.
      def adoption_info(concept, raw: nil)
        candidate_sources = managed_sources(concept)
        candidate_sources += localized_sources_raw(raw) if raw

        adopt = candidate_sources.find do |s|
          src = source_origin_source(s)
          src && (src.to_s.match?(/\AVIM|OIML V [12]/) || urn?(src))
        end

        return nil unless adopt
        {
          "kind"          => adoption_kind(source_origin_source(adopt)),
          "relationship"  => adoption_relationship(adopt),
          "modification"  => source_modification(adopt),
          "ref_source"    => source_origin_source(adopt),
          "ref_id"        => source_origin_id(adopt),
          "is_vimline"    => vimline_source?(source_origin_source(adopt)),
        }
      end

      def managed_sources(concept)
        srcs = concept.data&.sources
        return [] unless srcs
        srcs.respond_to?(:to_a) ? srcs.to_a : Array(srcs)
      end

      # Pull localized sources from the raw YAML hash. The localized doc is
      # the one with `data.definition` (vs. the managed doc with
      # `data.localized_concepts`).
      def localized_sources_raw(raw)
        return [] unless raw.is_a?(Array)
        loc_doc = raw.find { |d| d.is_a?(Hash) && d.dig("data", "definition") }
        return [] unless loc_doc
        data = loc_doc["data"] || {}
        # Source attribution can live in several places in vocab v3:
        #   - data.sources                       (concept-level)
        #   - data.definition[].sources          (per-paragraph)
        #   - data.notes[].sources / examples[].sources (per-note / per-example)
        out = []
        out.concat(Array(data["sources"]))
        Array(data["definition"]).each { |d| out.concat(Array(d.is_a?(Hash) ? d["sources"] : nil)) }
        Array(data["notes"]).each     { |n| out.concat(Array(n.is_a?(Hash) ? n["sources"] : nil)) }
        Array(data["examples"]).each  { |x| out.concat(Array(x.is_a?(Hash) ? x["sources"] : nil)) }
        out
      end

      def source_modification(src)
        if src.is_a?(Hash)
          src["modification"]
        elsif src.respond_to?(:modification)
          src.modification
        end
      end

      def urn?(s)
        s.is_a?(String) && s.start_with?("urn:oiml:pub:v:")
      end

      def vimline_source?(s)
        return false unless s.is_a?(String)
        s.start_with?("urn:oiml:pub:v:") || s.match?(/\AOIML V [12]/) || s.match?(/\AVIM[L]?\b/)
      end

      def adoption_kind(s)
        case s.to_s
        when /\AVIM[L]?\b/, /\AOIML V 2-200\b/, /urn:oiml:pub:v:2:/ then "vim"
        when /\AVIML\b/,    /\AOIML V 1\b/,    /urn:oiml:pub:v:1:/ then "viml"
        when /\AOIML [RDG]\b/                                    then "oiml_pub"
        else "other"
        end
      end

      # ConceptSource#status carries the adoption relationship in vocab v3:
      # "identical" = verbatim quote, "modified" = adapted with `modification`
      # text describing the change. Fall back to the source `type` field
      # ("authoritative"/"similar"/"derived") for older data without status.
      def adoption_relationship(src)
        if src.is_a?(Hash)
          return src["status"] if src["status"]
          return src["type"] if src["type"]
          return "authoritative"
        end
        status = src.respond_to?(:status) ? Array(src.status).first : nil
        return status if status
        type = src.respond_to?(:type) ? Array(src.type).first : nil
        type || "authoritative"
      end

      def source_origin_source(src)
        if src.is_a?(Hash)
          return src.dig("origin", "ref", "source")
        end
        ref = src.respond_to?(:origin) ? src.origin&.ref : nil
        ref&.respond_to?(:source) ? ref.source : nil
      end

      def source_origin_id(src)
        if src.is_a?(Hash)
          return src.dig("origin", "ref", "id")
        end
        ref = src.respond_to?(:origin) ? src.origin&.ref : nil
        ref&.respond_to?(:id) ? ref.id : nil
      end
    end
  end
end
