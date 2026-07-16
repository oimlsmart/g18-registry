# frozen_string_literal: true

# G 18 suggested-action model.
#
# An Action is a recommended editorial step that some audience (TC 1,
# a TC/SC secretary, or a Recommendation project team) should take for
# a specific term. Actions are computed once at export time and stored
# in terms.json; every UI page filters the same data for its audience.
#
# Action types (mutually exclusive — each term instance gets at most
# one of these):
#
#   upgrade_vim           — cites superseded VIM; available in VIM 2012
#   upgrade_viml          — cites superseded VIML; available in VIML 2022
#   removed               — not found in latest edition (deleted or renamed)
#   harmonize             — ≥ 2 distinct definitions across publications
#   standardize           — cited by ≥ 2 pubs, all identical, ready to confirm canonical
#   unique                — OIML-original, no VIM/VIML reference
#   aligned               — Case 1: designation + definition match current V1/V2
#   definition_diverges   — Case 3: designation matches, definition differs
#   fuzzy_adopt           — Case 4: similar designation exists in V1/V2
#   propose_v3            — Case 5: no V1/V2 match, OIML-specific
#
# Priorities: high / medium / low / info

module G18
  module Actions
    DIR = File.expand_path("actions", __dir__).freeze
    autoload :Action,    File.join(DIR, "action")
    autoload :Compiler,  File.join(DIR, "compiler")
    autoload :TermState, File.join(DIR, "term_state")
    autoload :Rules,     File.join(DIR, "rules")
  end
end
