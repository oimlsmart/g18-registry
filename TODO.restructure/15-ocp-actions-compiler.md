# 15 — Actions::Compiler OCP refactor

## Context
`lib/g18/actions/compiler.rb` uses procedural dispatch:
```ruby
def call
  actions = []
  actions.concat(alignment_action)
  actions.concat(vocab_actions)
  actions.concat(harmonize_action)
  actions.concat(standardize_action)
  actions.concat(unique_action) if ...
  actions.sort_by(&:priority_rank)
end
```

Adding a new rule = modifying the compiler. Violates OCP.

## Plan
Extract each `*_action` method into a Rule class under `G18::Actions::Rules::*`:

```ruby
module G18::Actions::Rules
  autoload :Alignment,   "g18/actions/rules/alignment"
  autoload :Vocab,       "g18/actions/rules/vocab"
  autoload :Harmonize,   "g18/actions/rules/harmonize"
  autoload :Standardize, "g18/actions/rules/standardize"
  autoload :Unique,      "g18/actions/rules/unique"

  ALL = [Alignment, Vocab, Harmonize, Standardize, Unique].freeze
end
```

Each rule:
```ruby
class Alignment
  def self.build(term)
    # was: alignment_action body
  end
end
```

Compiler:
```ruby
def call
  Rules::ALL.flat_map { |r| r.build(term_state) }.sort_by(&:priority_rank)
end
```

## Benefits
- New rule = new file + register in `ALL`. No modification of existing rules.
- Each rule has its own spec file.
- Shared term-state access via a struct or attr_reader.

## Migration
- Extract rules one at a time, verify specs pass after each
- Keep existing compiler_spec.rb green throughout
