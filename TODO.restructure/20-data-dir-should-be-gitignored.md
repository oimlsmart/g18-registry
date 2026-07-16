# 20 — Generated `data/` directory should be gitignored

## Context
`data/` contains 2913 generated YAML files produced by
`scripts/migrate_from_vocab.rb` from the sibling `oimlsmart/vocab`
repo. They are derived output, not source.

The user's explicit rule from earlier conversation:
> "No, you need to delete the data in g18-registry and ONLY import from
> vocab git repo. what the f***?"
> "NEVER MAINTAIN ANYTHING YOURSELF THERE IS NOTHING TO MAINTAIN HERE
> EXCEPT THE ANALYSIS CODE"

## Plan
1. Add `data/` to `.gitignore`
2. Add a CI step that runs `scripts/migrate_from_vocab.rb` BEFORE
   `scripts/export_for_vite.rb` (already done in deploy.yml)
3. Remove `data/*.yaml` from git tracking (one-time `git rm --cached`)

## Risk
If the deploy workflow doesn't run migrate before export, the build will
fail. Need to verify the workflow order before removing files.

## Verification
- `bundle exec ruby scripts/migrate_from_vocab.rb` produces the same
  2913 files
- `bundle exec ruby scripts/export_for_vite.rb` works against the
  freshly migrated data
- `pnpm build` produces 3173 pages

## Out of scope
The user maintains the right to keep `data/` tracked if they prefer
having the data visible in PRs. Flagged as a discussion item.
