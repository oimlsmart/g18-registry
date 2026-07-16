# frozen_string_literal: true

# Action rules. Each rule is a module with a `self.call(state)` method
# that returns an Array of Actions. Rules are independent — they don't
# see each other's output. The Compiler aggregates all results.
#
# To add a new rule:
#   1. Create lib/g18/actions/rules/<name>.rb defining `module Rules::Name`
#   2. Add `autoload :Name, ...` below
#   3. Append `Name` to ALL
#
# No existing rule file needs to be modified (OCP).

module G18
  module Actions
    module Rules
      DIR = File.expand_path("rules", __dir__).freeze

      autoload :Alignment,   File.join(DIR, "alignment")
      autoload :Vocab,       File.join(DIR, "vocab")
      autoload :Harmonize,   File.join(DIR, "harmonize")
      autoload :Standardize, File.join(DIR, "standardize")
      autoload :Unique,      File.join(DIR, "unique")

      ALL = [
        Alignment,
        Vocab,
        Harmonize,
        Standardize,
        Unique,
      ].freeze
    end
  end
end
