# frozen_string_literal: true

require_relative "../action"

module G18
  module Actions
    module Rules
      # Fallback for OIML-original terms with no VIM/VIML reference.
      # The description carries near-miss guidance when the export
      # pipeline found a similar VIM/VIML designation via fuzzy match.
      module Unique
        module_function

        def call(state)
          return [] unless applies?(state)
          [Action.new(
            type: :unique,
            priority: :info,
            description: compose_description(state),
            publication_ids: state.publication_ids,
          )]
        end

        def applies?(state)
          # Fire for OIML-original terms OR when no other rule produced
          # an action (catch-all so every term has at least one action).
          state.oiml_specific? ||
            (state.official_concept.nil? && state.kind != "defined_in_vim" && state.kind != "defined_in_viml")
        end

        def compose_description(state)
          candidate = select_near_miss(state)
          tail = state.has_divergence ?
            " Check divergent definitions and update, or document why divergence is intentional." :
            " Check divergent definitions and confirm authoritative source."
          if candidate.nil?
            "Not in VIML/VIM. Candidate term for V 1/V 2/V 3?#{tail}"
          elsif candidate_match_type(candidate) == "exact"
            "OIML-original term, but #{candidate_label(candidate)} has an exact match: '#{candidate_designation(candidate)}'. " \
            "Re-link to #{candidate_label(candidate)} or document why this term should remain OIML-specific.#{tail}"
          else
            "OIML-original term. #{candidate_label(candidate)} has a similar term: '#{candidate_designation(candidate)}'. " \
            "Reconcile with #{candidate_label(candidate)}, document as a specific term (candidate for V 3), or confirm OIML as authoritative.#{tail}"
          end
        end

        def select_near_miss(state)
          presence = state.vocab_presence || {}
          vim = presence["vim"]
          viml = presence["viml"]
          # Prefer exact over fuzzy; VIML > VIM for legal-metrology context.
          exact = [viml, vim].find { |c| c && (c["match_type"] || c[:match_type]) == "exact" }
          return exact if exact
          [viml, vim].compact.first
        end

        def candidate_match_type(c)
          c["match_type"] || c[:match_type]
        end

        def candidate_designation(c)
          c["designation"] || c[:designation]
        end

        def candidate_label(c)
          c["latest_label"] || c[:latest_label]
        end
      end
    end
  end
end
