# frozen_string_literal: true

require "yaml"

module G18
  module Export
    # Enriches publication instances with sourced_from chains extracted
    # from raw vocab-repo YAML. glossarist can't parse concept files that
    # carry lineage sources, so this reader reads the raw YAML directly
    # and threads the sourced_from into matching publication instances.
    class SourcedFromEnricher
      DATASETS = %w[oiml-complete].freeze

      def initialize(vocab_root:)
        @vocab_root = vocab_root
      end

      # Mutates `terms` in-place: sets `sourced_from` on each matching
      # publication instance that doesn't already have one.
      def call(terms)
        term_by_slug = terms.each_with_object({}) { |t, h| h[t["slug"]] = t }
        DATASETS.each do |dataset|
          concepts_dir = File.join(@vocab_root, dataset, "concepts")
          next unless Dir.exist?(concepts_dir)
          enrich_from_dataset(concepts_dir, "complete", term_by_slug)
        end
      end

      private

      def enrich_from_dataset(concepts_dir, edition, term_by_slug)
        Dir.glob(File.join(concepts_dir, "*.yaml")).each do |vfile|
          raw = read_yaml(vfile)
          next unless raw
          slug = derive_slug(raw)
          next unless slug
          term = term_by_slug[slug]
          next unless term
          sf = extract_sourced_from(raw)
          next if sf.empty?
          apply_sourced_from(term, edition, sf)
        end
      end

      def read_yaml(path)
        vraw = File.read(path, encoding: "utf-8")
        vdocs = YAML.safe_load_stream(vraw, aliases: true, permitted_classes: [Date, Time])
        vdocs.find { |d| d.is_a?(Hash) && d.dig("data", "definition") }
      rescue StandardError
        nil
      end

      def derive_slug(loc_doc)
        terms_data = loc_doc.dig("data", "terms") || []
        pref = terms_data.find { |t| (t["normative_status"] || "").include?("preferred") } || terms_data.first
        return nil unless pref && pref["designation"]
        pref["designation"].to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      end

      def extract_sourced_from(loc_doc)
        sources = Array(loc_doc.dig("data", "sources"))
        sf = []
        sources.each do |s|
          sfa = s.is_a?(Hash) ? s["sourced_from"] : nil
          next unless sfa.is_a?(Array)
          sfa.each do |ref|
            r = ref.is_a?(Hash) ? (ref["ref"] || ref) : ref
            src = r.is_a?(Hash) ? r["source"] : nil
            next unless src
            sf << { "source" => src }
          end
        end
        sf
      end

      def apply_sourced_from(term, edition, sf)
        (term["publications"] || []).each do |p|
          next unless p["edition"] == edition
          next if p["sourced_from"]
          p["sourced_from"] = sf
        end
      end
    end
  end
end
