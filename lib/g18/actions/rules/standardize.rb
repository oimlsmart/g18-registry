# frozen_string_literal: true

require_relative "../action"

module G18
  module Actions
    module Rules
      # Stability signal. Fires when ≥ 2 publication instances share an
      # identical definition — ready to confirm as canonical. Distinct
      # from Harmonize, which fires on divergent definitions.
      module Standardize
        module_function

        def call(state)
          return [] if state.pubs.size < 2
          defs = state.distinct_definitions
          return [] unless defs.size == 1
          unique_pub_ids = state.publication_ids
          description = if unique_pub_ids.size == 1
            "Cited by 1 publication across #{state.pubs.size} editions; definition stable."
          else
            "All #{unique_pub_ids.size} publications share the same definition. Ready to standardize."
          end
          [Action.new(
            type: :standardize,
            priority: :info,
            description: description,
            publication_ids: unique_pub_ids,
          )]
        end
      end
    end
  end
end
