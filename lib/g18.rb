# frozen_string_literal: true

# Top-level G 18 namespace. Sets up autoloads for every public module
# so callers can `require_relative "lib/g18"` once and reach any
# constant via `G18::Whatever`.
#
# Per the project rule, internal library code never uses
# `require_relative` for sibling files. Each parent module's file
# declares its own children's autoloads (see lib/g18/migration.rb,
# lib/g18/actions.rb, lib/g18/tc_sc.rb, etc.).

module G18
  LIB_DIR = __dir__.freeze

  # Top-level modules — each lives in its own file under lib/g18/.
  autoload :Vocabulary,      File.join(LIB_DIR, "g18", "vocabulary")
  autoload :FuzzyMatch,      File.join(LIB_DIR, "g18", "fuzzy_match")
  autoload :TcSc,            File.join(LIB_DIR, "g18", "tc_sc")
  autoload :Migration,       File.join(LIB_DIR, "g18", "migration")
  autoload :Actions,         File.join(LIB_DIR, "g18", "actions")
  autoload :Export,          File.join(LIB_DIR, "g18", "export")
  autoload :Site,            File.join(LIB_DIR, "g18", "site")
  autoload :Consistency,     File.join(LIB_DIR, "g18", "consistency")

  # Sub-namespace with its own autoload tree.
  module Model
    MODEL_DIR = File.join(LIB_DIR, "g18", "model").freeze
    autoload :Identifier, File.join(MODEL_DIR, "identifier")
    autoload :PubId,      File.join(MODEL_DIR, "pub_id")
  end
end
