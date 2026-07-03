# frozen_string_literal: true

# Cross-term ID conflict detection.
#
# Two types of conflict:
#
#   1. Raw ID conflict — one source identifier assigned to two semantically
#      different concepts (a numbering error in the source publication).
#      In the 2010 dataset these are encoded with an `a`/`b` suffix split
#      (e.g. identifier `00474a` vs `00474b`, both sharing base number
#      `00474`). In the 202X dataset the same kind of collision is encoded
#      with a `-RXXX-N` publication suffix (e.g. `02344-R049-1` vs
#      `02344-R099-1`, both sharing base number `02344`).
#
#   2. Designation collision — same concept cited under multiple distinct IDs
#      (handled separately, on the harmonisation worklist).
#
# The detector strips both styles of disambiguation suffix to surface the
# underlying base number, then reports any base that has multiple distinct
# (designation, source) tuples.

module G18
  module Migration
    module Conflicts
      module_function

      # Strip the disambiguation suffixes used by the dataset to recover the
      # underlying G 18 base number:
      #   "00474a"        -> "00474"   (2010 a/b split)
      #   "00474b"        -> "00474"
      #   "02344-R049-1"  -> "02344"   (202X publication split)
      #   "02344-R099-1"  -> "02344"
      #   "00474"         -> "00474"   (already canonical)
      def base_identifier(id)
        id.to_s
          .sub(/-[A-Z][0-9]+(-\d+)?\z/, "")   # -R049-1 / -R108
          .sub(/[a-z]\z/, "")                 # trailing a/b suffix
      end

      # Returns `{ edition_name => [{ id:, concepts: [...] }, ...] }` for
      # every base number that has more than one distinct designation in
      # that edition.
      def detect_id_conflicts(entries_by_edition)
        conflicts = {}
        entries_by_edition.each do |edition, entries|
          by_base = Hash.new { |h, k| h[k] = [] }
          entries.each do |e|
            id = Loaders.identifier(e[:concept])
            next unless id
            designation = Loaders.preferred_designation(e[:concept])
            next unless designation
            source = Loaders.source_ref(e[:concept])
            raw_id = id
            tuple = { designation: designation, source: source, raw_id: raw_id }
            by_base[base_identifier(id)] << tuple
          end
          ed_conflicts = by_base.each_with_object([]) do |(base, arr), out|
            distinct = arr.uniq { |x| [x[:designation], x[:source]] }
            next unless distinct.size > 1
            out << { id: base, concepts: distinct.sort_by { |x| x[:designation].downcase } }
          end
          next if ed_conflicts.empty?
          conflicts[edition] = ed_conflicts.sort_by { |c| c[:id] }
        end
        conflicts
      end
    end
  end
end
