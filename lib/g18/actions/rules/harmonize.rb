# frozen_string_literal: true

require_relative "../action"

module G18
  module Actions
    module Rules
      # Within-edition divergence. Fires when ≥ 2 distinct definitions
      # appear in the SAME edition. Cross-edition definition differences
      # are legitimate editorial evolution (TC 1 rewording between 2010
      # and 202X) and do NOT trigger this rule.
      module Harmonize
        module_function

        def call(state)
          return [] if state.pubs.size < 2
          per_edition = state.distinct_definitions_per_edition
          worst_edition, worst_set = per_edition.max_by { |_, d| d.size }
          return [] unless worst_set && worst_set.size >= 2
          pubs_in_edition = state.pubs.count { |p| p["edition"] == worst_edition }
          priority = worst_set.size >= 5 ? :high : (worst_set.size >= 3 ? :medium : :low)
          pub_ids = state.pubs
            .select { |p| p["edition"] == worst_edition }
            .map { |p| p["publication_id"] }
            .uniq
          [Action.new(
            type: :harmonize,
            priority: priority,
            description: "#{worst_set.size} distinct definitions within #{worst_edition} across #{pubs_in_edition} publications. " \
                         "Update, or document why divergence is intentional.",
            publication_ids: pub_ids,
          )]
        end
      end
    end
  end
end
