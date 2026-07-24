# frozen_string_literal: true

module G18
  module Migration
    # Classifies concept sources (where a definition came from) and
    # extracts structured data from glossarist ConceptSource objects.
    #
    # Handles both raw Hash (from YAML) and typed Glossarist::ConceptSource
    # inputs. Previously mixed into Loaders (536 lines); extracted for
    # MECE — these methods form a cohesive concern about provenance.
    module SourceClassification
      module_function

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
          ref = src.dig("origin", "ref")
          return ref if ref.is_a?(String)
          return ref["source"] if ref.is_a?(Hash)
          nil
        end
        ref = src.respond_to?(:origin) ? src.origin&.ref : nil
        ref&.respond_to?(:source) ? ref.source : nil
      end

      def source_origin_id(src)
        if src.is_a?(Hash)
          ref = src.dig("origin", "ref")
          return nil if ref.is_a?(String)
          return ref["id"] if ref.is_a?(Hash)
          nil
        end
        ref = src.respond_to?(:origin) ? src.origin&.ref : nil
        ref&.respond_to?(:id) ? ref.id : nil
      end
    end
  end
end
