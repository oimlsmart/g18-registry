# 14 — Set up top-level lib/g18.rb autoload

## Context
Per the user's global rule, internal library code must use `autoload`, not
`require_relative`. Currently:
- `lib/g18/export/matcher.rb` does `require_relative "../vocabulary"`
- `lib/g18/export/term_processor.rb` does `require_relative "../actions"`
- Several others

These violate the rule.

## Plan
1. Create `lib/g18.rb` that sets up autoloads for all top-level modules:
   - Vocabulary, FuzzyMatch, Migration, Actions, Export, Model, Site, etc.
2. Remove `require_relative` lines from `lib/g18/**/*.rb` that reference sibling lib files
3. Keep `require` for stdlib (yaml, json, set, etc.) and external gems (plurimath, etc.)
4. Update scripts to `require_relative "../lib/g18"` (one line)

## Verification
- `bundle exec rspec` passes
- `bundle exec ruby scripts/export_for_vite.rb` produces identical output
