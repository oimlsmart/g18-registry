# frozen_string_literal: true

module G18
  module Export
    # De-duplicates publication instances by (publication_id, clause).
    # The same pub+clause across G 18 editions should count as ONE instance.
    module Deduplicator
      module_function

      def by_pub_and_clause(pubs)
        pubs.each_with_object({}) do |p, h|
          key = "#{p['publication_id']}|#{p['clause']}"
          h[key] ||= p
        end.values
      end

      # Returns the set of distinct non-empty definition strings after
      # stripping {{xref}} markup and whitespace.
      def distinct_definitions(pubs)
        pubs
          .map { |p| (p["definition"] || "").gsub(/\{\{[^}]+\}\}/, "").strip }
          .reject(&:empty?)
          .uniq
      end
    end
  end
end
