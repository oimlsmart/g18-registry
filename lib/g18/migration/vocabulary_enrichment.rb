# frozen_string_literal: true

# VIM/VIML authoritative-concept enrichment.
# Loads the official definition text from the sibling vocab checkout so term
# pages can render the baseline without a runtime fetch.

module G18
  module Migration
    module VocabularyEnrichment
      module_function

      def vocab_concept_url(urn, id)
        dataset = URN_TO_DATASET[urn]
        return nil unless dataset && id
        "#{VOCAB_BASE_URL}/#{dataset}/concept/#{id}"
      end

      def kind_for_urn(urn)
        case urn
        when /\Aurn:oiml:pub:v:1:/ then "defined_in_viml"
        when /\Aurn:oiml:pub:v:2:/ then "defined_in_vim"
        else "undefined"
        end
      end

      # Loads the official definition text for a VIM/VIML concept.
      # Returns nil if the file isn't found or has no English definition.
      def load_official_definition_text(vocab_dir, urn, concept_id)
        dataset = URN_TO_DATASET[urn]
        return nil unless dataset && concept_id && vocab_dir
        path = File.join(vocab_dir, dataset, "concepts", "#{concept_id}.yaml")
        return nil unless File.exist?(path)
        docs = begin
          YAML.safe_load_stream(File.read(path), filename: path, aliases: true)
        rescue Psych::SyntaxError
          nil
        end
        return nil unless docs
        loc = docs.find { |d| d && d.is_a?(Hash) && d.dig("data", "definition") }
        return nil unless loc
        defs = loc.dig("data", "definition") || []
        text = defs.map { |d| d["content"] if d.is_a?(Hash) }.compact.join("\n").strip
        text.empty? ? nil : text
      end

      # Enrich a VIM/VIML reference (URN + concept id) with edition metadata
      # so the term YAML carries everything the template needs.
      def enrich_authority_ref(vocab_dir, ref)
        return ref unless ref.is_a?(Hash)
        urn = ref["source"]
        return ref unless G18::Vocabulary.vocab(urn)
        concept_id = ref["id"]
        enriched = ref.dup
        enriched["definition_text"] ||= load_official_definition_text(vocab_dir, urn, concept_id)
        enriched["edition_label"] = G18::Vocabulary.label(urn)
        enriched["vocab"]         = G18::Vocabulary.vocab(urn).to_s
        enriched["role"]          = G18::Vocabulary.role(urn).to_s
        enriched["year"]          = G18::Vocabulary.year(urn)
        enriched
      end
    end
  end
end
