# frozen_string_literal: true

require "open3"
require "json"

module G18
  module Export
    # Computes per-concept diffs between historic and latest V1/V2 editions
    # via the glossarist-js compute-concept-diffs.mjs script. The diff
    # describes what changed in the concept version series (designation,
    # definition, notes) — used by the term detail page.
    class ConceptDiffer
      DIFF_PAIRS = {
        vim: [["vim-1993", "vim-2012"], ["vim-2007", "vim-2012"], ["vim-2010", "vim-2012"]],
        viml: [["viml-2000", "viml-2022"], ["viml-2013", "viml-2022"]],
      }.freeze

      def initialize(script_dir:, vocab_root:)
        @script_dir = script_dir
        @vocab_root = vocab_root
      end

      # Returns { "old_dir->new_dir" => { concept_id => diff, ... }, ... }
      def call
        diff_script = File.expand_path("compute-concept-diffs.mjs", @script_dir)
        DIFF_PAIRS.each_with_object({}) do |(_vocab, pairs), acc|
          pairs.each do |old_dir, new_dir|
            old_path = File.join(@vocab_root, old_dir, "concepts")
            new_path = File.join(@vocab_root, new_dir, "concepts")
            next unless Dir.exist?(old_path) && Dir.exist?(new_path)
            diff_key = "#{old_dir}->#{new_dir}"
            acc[diff_key] = compute_diff(diff_script, old_path, new_path, diff_key)
          end
        end
      end

      private

      def compute_diff(script, old_path, new_path, diff_key)
        stdout, status = Open3.capture2("node", script, old_path, new_path)
        return {} unless status.success?
        JSON.parse(stdout)
      rescue StandardError => e
        warn "  WARNING: concept diff #{diff_key} failed: #{e.message}"
        {}
      end
    end
  end
end
