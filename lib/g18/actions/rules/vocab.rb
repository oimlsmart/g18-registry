# frozen_string_literal: true

require_relative "../action"

module G18
  module Actions
    module Rules
      # Vocabulary-supersession actions. Fires when a term cites a VIM/VIML
      # edition older than the current one. Produces:
      #
      #   upgrade_vim  / upgrade_viml — term exists in latest; just re-cite
      #   removed                — term no longer in latest; verify rename
      #
      # When `canonical_mismatch` is set (a fuzzy rename candidate), the
      # `removed` description surfaces the likely new designation.
      module Vocab
        module_function

        def call(state)
          return [] unless state.latest_check && state.official_concept
          lc = state.latest_check
          out = []
          cited_label = state.official_concept["edition_label"] || state.official_concept["source"]
          cited_urn = state.official_concept["source"]
          latest_label = lc["latest_label"]

          if lc["found"]
            out.concat(found_in_latest_actions(state, cited_label, cited_urn, latest_label))
          else
            out.concat(not_found_in_latest_actions(state, cited_label, latest_label))
          end
          out
        end

        def found_in_latest_actions(state, cited_label, cited_urn, latest_label)
          vocab = state.latest_check["vocab"]
          return [] unless state.superseded_urn?(cited_urn, vocab: vocab&.to_sym)
          action_type = vocab == "vim" ? :upgrade_vim : :upgrade_viml
          vocab_short = vocab == "vim" ? "VIM" : "VIML"
          tail = state.has_divergence ?
            " Update citation, or document why divergence is intentional." :
            " Update citation."
          [Action.new(
            type: action_type,
            priority: :high,
            description: "#{vocab_short} reference outdated — #{cited_label} superseded by #{latest_label}.#{tail}",
            publication_ids: state.publication_ids,
            vocab_ref: { "latest_label" => latest_label, "cited_label" => cited_label },
          )]
        end

        def not_found_in_latest_actions(state, cited_label, latest_label)
          mismatch = state.canonical_mismatch
          if mismatch
            [Action.new(
              type: :removed,
              priority: :high,
              description: "Not in #{mismatch['latest_label']}. #{mismatch['latest_label']} term is '#{mismatch['designation']}'. " \
                           "Verify rename or reallocate.#{mismatch_tail(state)}",
              publication_ids: state.publication_ids,
              vocab_ref: { "latest_label" => mismatch["latest_label"], "cited_label" => cited_label },
            )]
          else
            tail = state.has_divergence ?
              " Update the G 18 citation, or document why divergence is intentional." :
              " Verify or reallocate."
            [Action.new(
              type: :removed,
              priority: :high,
              description: "In #{cited_label}; removed from #{latest_label}.#{tail}",
              publication_ids: state.publication_ids,
              vocab_ref: { "latest_label" => latest_label, "cited_label" => cited_label },
            )]
          end
        end

        def mismatch_tail(state)
          state.has_divergence ?
            " Update or document why divergence is intentional." :
            ""
        end
      end
    end
  end
end
