# frozen_string_literal: true

module G18
  module Actions
    # Immutable snapshot of every input the rules need. Built once per
    # term; passed to each Rule module. Memoizes derived computations
    # (distinct definitions per edition, has_divergence) so multiple
    # rules don't recompute them.
    class TermState
      VIM_CURRENT = "urn:oiml:pub:v:2:2012"
      VIML_CURRENT = "urn:oiml:pub:v:1:2022"

      attr_reader :term, :data, :pubs, :official_concept, :latest_check,
                  :kind, :alignment, :vocab_presence, :canonical_mismatch

      def initialize(term:)
        @term = term || {}
        @data = @term["data"] || {}
        @pubs = @data["publications"] || []
        @official_concept = @data["official_concept"]
        @latest_check = @term["latest_check"] || @data["latest_check"]
        @kind = @data["kind"] || "oiml_original"
        @alignment = @term["alignment"] || @data["alignment"]
        @vocab_presence = @term["vocab_presence"] || {}
        @canonical_mismatch = @term["canonical_mismatch"]
      end

      def self.from(term) = new(term: term)

      # Per-edition distinct-definition counts. Cross-edition definition
      # changes are legitimate editorial evolution, not harmonisation
      # targets — only WITHIN-edition divergence counts.
      def distinct_definitions_per_edition
        @distinct_definitions_per_edition ||= begin
          pubs.group_by { |p| p["edition"] }.transform_values do |ed_pubs|
            ed_pubs
              .map { |p| normalize_definition(p["definition"]) }
              .reject(&:empty?)
              .uniq
          end
        end
      end

      def distinct_definitions
        @distinct_definitions ||= pubs
          .map { |p| normalize_definition(p["definition"]) }
          .reject(&:empty?)
          .uniq
      end

      def has_divergence
        @has_divergence ||= distinct_definitions_per_edition.values.any? { |d| d.size >= 2 }
      end

      def oiml_specific?
        kind == "oiml_original" || kind == "undefined"
      end

      def publication_ids
        @publication_ids ||= pubs.map { |p| p["publication_id"] }.uniq
      end

      # True if `urn` is for a superseded VIM/VIML edition. Tolerates
      # non-URN source strings like "OIML V 2-200:2007".
      def superseded_urn?(urn, vocab:)
        return false unless urn
        current = vocab == :vim ? VIM_CURRENT : VIML_CURRENT
        return true if urn.match?(/V 2-200:(1993|2007|2010)/) && vocab == :vim
        return true if urn.match?(/V 1:(1968|2000|2013)/) && vocab == :viml
        urn != current
      end

      # Normalize VIM cross-reference markup so definitions compare
      # correctly regardless of {{id,text}} wrapping.
      def normalize_definition(text)
        return "" unless text.is_a?(String)
        text.gsub(/\{\{[^,}]+,([^}]+)\}\}/, '\1').strip
      end
    end
  end
end
