# frozen_string_literal: true

# G 18 dataset migration.
#
# Source: oimlsmart/vocab datasets/g18-{2010,202X}/.
# Output: per-term YAML files written to the configured output directory.
#
# One source file = one (term, publication) instance. The migration groups
# instances by lowercased preferred designation and emits one file per
# unique term. See `G18::Migration::Runner.run` for the orchestrator.
#
# Submodules (autoloaded):
#   Result                 — Struct returned by `run`
#   Normalize              — designation + math normalization
#   Loaders                — YAML/bibliography loading and field extraction
#   Builders               — per-term / per-publication record construction
#   VocabularyEnrichment   — VIM/VIML authoritative-concept enrichment
#   Conflicts              — cross-term ID conflict detection
#   Runner                 — the `run` orchestrator

require "yaml"
require "digest"
require "fileutils"
require "set"

module G18
  module Migration
    SOURCE_INSTANCE_COUNT = 2125
    EXPECTED_RELATED_EDGES = 101

    URN_TO_DATASET = {
      "urn:oiml:pub:v:1:1968" => "viml-1968",
      "urn:oiml:pub:v:1:2000" => "viml-2000",
      "urn:oiml:pub:v:1:2013" => "viml-2013",
      "urn:oiml:pub:v:1:2022" => "viml-2022",
      "urn:oiml:pub:v:2:1993" => "vim-1993",
      "urn:oiml:pub:v:2:2007" => "vim-2007",
      "urn:oiml:pub:v:2:2010" => "vim-2010",
      "urn:oiml:pub:v:2:2012" => "vim-2012",
    }.freeze

    VOCAB_BASE_URL = "https://www.oimlsmart.org/vocab/dataset"

    # Absolute paths so autoload works regardless of $LOAD_PATH.
    DIR = File.expand_path("migration", __dir__).freeze

    autoload :Result,               File.join(DIR, "result")
    autoload :Normalize,            File.join(DIR, "normalize")
    autoload :Loaders,              File.join(DIR, "loaders")
    autoload :Builders,             File.join(DIR, "builders")
    autoload :VocabularyEnrichment, File.join(DIR, "vocabulary_enrichment")
    autoload :Conflicts,            File.join(DIR, "conflicts")
    autoload :Runner,               File.join(DIR, "runner")
    autoload :Report,               File.join(DIR, "report")

    # Convenience delegator so existing call sites continue to work
    # (`G18::Migration.run(...)`).
    def self.run(**kwargs)
      Runner.run(**kwargs)
    end
  end
end
