# frozen_string_literal: true

require_relative "../action"

module G18
  module Actions
    module Rules
      # 5-case alignment classification actions. Consumes the alignment
      # data pre-computed by G18::Export::Matcher and emits:
      #
      #   Case 1 -> aligned (info)
      #   Case 3 -> definition_diverges (high)
      #   Case 4 -> fuzzy_adopt (medium)
      #   Case 5 -> propose_v3 (low)
      #
      # Case 2 (historic match) is not yet implemented in the matcher —
      # see TODO 18.
      module Alignment
        module_function

        def call(state)
          return [] unless state.alignment
          ac = state.alignment["case"]
          status = state.alignment["alignment"]
          vocab = state.alignment["matched_vocab"]
          label = vocab_label(vocab)
          term_name = state.data["term"] || state.data["name"] || "this term"

          case ac
          when 1
            [Action.new(type: :aligned, priority: :info,
              description: "Designation and definition match current #{label}. No action needed.")]
          when 3
            [Action.new(type: :definition_diverges, priority: :high,
              description: "Designation matches #{label} but definition differs. " \
                           "Adopt the #{label} concept, or differentiate the designation and propose to V3.")]
          when 4
            matched = matched_designation(state, vocab)
            [Action.new(type: :fuzzy_adopt, priority: :medium,
              description: "Designation is similar to a #{label} term#{matched ? " ('#{matched}')" : ''}. " \
                           "Adopt the #{label} term, or propose to V3 as sufficiently different.")]
          when 5
            [Action.new(type: :propose_v3, priority: :low,
              description: "No V1/V2 match. '#{term_name}' is OIML-specific. " \
                           "Propose for the future V3 vocabulary.")]
          else
            []
          end
        end

        def vocab_label(vocab)
          case vocab
          when "viml" then "VIML 2022"
          when "vim"  then "VIM 2012"
          else "V1/V2"
          end
        end

        def matched_designation(state, vocab)
          presence = state.vocab_presence || {}
          if vocab == "viml"
            presence["viml"]&.dig("designation") || presence["vim"]&.dig("designation")
          else
            presence["vim"]&.dig("designation") || presence["viml"]&.dig("designation")
          end
        end
      end
    end
  end
end
