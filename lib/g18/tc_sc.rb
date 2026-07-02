# frozen_string_literal: true

require "yaml"
require "fileutils"

module G18
  # Maintains the local mirror of OIML bibliography enriched with TC/SC
  # attribution. The vocab repo's `datasets/g18/bibliography.yaml` is the
  # canonical upstream source for id/reference/link; this file mirrors it
  # into the registry and adds the `tc_sc` field that OIML needs to provide.
  module TcSc
    # Map of publication-id -> tc_sc string. Populated where OIML has publicly
    # confirmed attribution (B 10 series, D 11, etc.). Anything not in this
    # map stays blank for OIML to fill in. See tc-sc/README.md.
    KNOWN_TC_SC = {
      # B 10 series, per OIML publications list
      "OIML B 10-1:2004" => "TC 3/SC 2",
      "OIML B 10-2:2007" => "TC 3/SC 2",
    }.freeze

    module_function

    def load_vocab_bibliography(vocab_dir)
      path = File.join(vocab_dir, "bibliography.yaml")
      entries = YAML.safe_load(File.read(path), aliases: true) || []
      entries.each_with_object({}) { |e, h| h[e["id"]] = e }
    end

    def load_local(path)
      return {} unless File.exist?(path)
      parsed = YAML.safe_load(File.read(path), aliases: true)
      entries =
        case parsed
        when Array then parsed
        when Hash then [parsed]
        else []
        end
      entries.each_with_object({}) { |e, h| h[e["id"]] = e if e.is_a?(Hash) }
    end

    # Merge vocab bibliography with the local overrides. Preserves existing
    # tc_sc values from the local file; pre-populates known values from
    # KNOWN_TC_SC; leaves the rest blank for editor fill-in.
    def merge(vocab_bib, local_bib)
      vocab_bib.values.map do |entry|
        id = entry["id"]
        existing_tc_sc = local_bib[id] && local_bib[id]["tc_sc"]
        ref = entry["reference"] || id
        {
          "id"          => id,
          "reference"   => ref,
          "link"        => entry["link"],
          "tc_sc"       => existing_tc_sc || KNOWN_TC_SC[ref] || "",
          "notes"       => (local_bib[id] && local_bib[id]["notes"]) || "",
        }
      end.sort_by { |e| e["id"] }
    end

    def serialize(entries)
      header = <<~YAML
        # TC/SC attribution for OIML publications referenced by G 18.
        #
        # Canonical upstream source: oimlsmart/vocab datasets/g18/bibliography.yaml
        # (id, reference, link). This file mirrors that and adds the `tc_sc` field
        # that OIML central secretariat needs to confirm.
        #
        # Regenerate with: scripts/sync_tc_sc.rb
        # Validate with:   scripts/validate_tc_sc.rb
        #
        # Convention:
        #   tc_sc: ""      — not yet attributed; needs OIML confirmation
        #   tc_sc: "TC X"  — single TC attribution
        #   tc_sc: "TC X/SC Y" — TC with subcommittee
        #   tc_sc: "TC X; TC Y" — multiple TCs (separate with semicolons)
        #   notes: free-form editor note (source, uncertainty, etc.)

      YAML
      body = YAML.dump(
        entries.map { |e|
          { "id" => e["id"], "reference" => e["reference"], "link" => e["link"], "tc_sc" => e["tc_sc"], "notes" => e["notes"] }
        }
      )
      header + body
    end

    def sync(vocab_dir:, output_path:)
      vocab_bib = load_vocab_bibliography(vocab_dir)
      local_bib = load_local(output_path)
      FileUtils.mkdir_p(File.dirname(output_path))
      merged = merge(vocab_bib, local_bib)
      File.write(output_path, serialize(merged))
      populated = merged.count { |e| !e["tc_sc"].to_s.empty? }
      total = merged.size
      {
        total: total,
        populated: populated,
        blank: total - populated,
        path: output_path,
      }
    end
  end
end
