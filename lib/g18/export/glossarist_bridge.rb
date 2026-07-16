# frozen_string_literal: true

require "open3"
require "json"

module G18
  module Export
    # Bridge to glossarist-js (Node.js) for concept loading. glossarist-js
    # correctly parses concept YAML files including localized designations,
    # notes, examples — better than hand-rolled Ruby YAML parsing.
    #
    # The bridge loads a full dataset ONCE and caches the result; subsequent
    # lookups by concept id are then O(1).
    class GlossaristBridge
      def initialize(script_dir:, vocab_root:)
        @script_dir = script_dir
        @vocab_root = vocab_root
        @cache = {}
      end

      # Load the designation index and full concept data for a concepts dir.
      # Returns [{designation => {id:, definition:}}, {id => full_concept}].
      def load_index(concepts_dir)
        @cache[concepts_dir] ||= build_index_for(concepts_dir)
      end

      # Look up a single concept by id within a dataset (e.g. "vim-2012").
      # Loads the dataset lazily and caches.
      def lookup_concept(dataset_dir, concept_id)
        return nil unless concept_id
        concepts_dir = File.join(@vocab_root, dataset_dir, "concepts")
        _, full = load_index(concepts_dir)
        full[concept_id]
      end

      private

      def build_index_for(concepts_dir)
        return [{}, {}] unless Dir.exist?(concepts_dir)
        stdout, status = Open3.capture2("node", "#{@script_dir}/load-vocab-concepts.mjs", concepts_dir, "full")
        return [{}, {}] unless status.success?
        full = JSON.parse(stdout)
        [build_designation_index(full), full]
      rescue JSON::ParserError, StandardError
        [{}, {}]
      end

      def build_designation_index(full)
        idx = {}
        full.each do |id, langs|
          eng = langs["eng"] || langs.values&.first
          next unless eng
          pref = (eng["designations"] || []).find { |d| d["status"] == "preferred" } || (eng["designations"] || [])&.first
          next unless pref&.dig("text")
          defn = (eng["definitions"] || []).join("\n").strip
          idx[pref["text"].downcase.strip] = { id: id, definition: defn }
        end
        idx
      end
    end
  end
end
