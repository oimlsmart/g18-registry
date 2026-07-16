# frozen_string_literal: true

require "yaml"
require "set"

module G18
  module TcSc
    # Verifies tc-sc/publications.yaml is in sync with the upstream vocab
    # bibliography and reports TC/SC coverage. Returns a structured result.
    module Validate
      Result = Struct.new(:ok, :vocab_ids, :local_ids, :missing, :extra, :blank_tc_sc, :populated_tc_sc, :total, keyword_init: true)

      module_function

      def call(vocab_dir:, local_path:)
        vocab_bib = TcSc.load_vocab_bibliography(vocab_dir)
        local_bib = TcSc.load_local(local_path)
        vocab_ids = vocab_bib.keys.to_set
        local_ids = local_bib.keys.to_set
        missing = (vocab_ids - local_ids).to_a.sort
        extra = (local_ids - vocab_ids).to_a.sort
        blank = local_bib.values.select { |e| (e["tc_sc"] || "").strip.empty? }
        populated = local_bib.values.reject { |e| (e["tc_sc"] || "").strip.empty? }
        Result.new(
          ok: missing.empty? && extra.empty?,
          vocab_ids: vocab_ids.to_a.sort,
          local_ids: local_ids.to_a.sort,
          missing: missing,
          extra: extra,
          blank_tc_sc: blank,
          populated_tc_sc: populated,
          total: local_bib.size,
        )
      end

      def render_report(result, io: $stdout)
        io.puts "TC/SC validator report"
        io.puts "-----------------------"
        io.puts "Total publications in tc-sc/publications.yaml: #{result.total}"
        io.puts "TC/SC populated: #{result.populated_tc_sc.size}"
        io.puts "TC/SC blank (awaiting OIML confirmation): #{result.blank_tc_sc.size}"
        io.puts
        if result.missing.any?
          io.puts "MISSING from local (present in vocab bibliography, not mirrored):"
          result.missing.each { |id| io.puts "  - #{id}" }
        end
        if result.extra.any?
          io.puts "EXTRA in local (no longer in vocab bibliography):"
          result.extra.each { |id| io.puts "  - #{id}" }
        end
        io.puts "Overall: #{result.ok ? 'PASS (in sync)' : 'FAIL (out of sync — re-run scripts/sync_tc_sc.rb)'}"
        result.ok
      end
    end
  end
end
