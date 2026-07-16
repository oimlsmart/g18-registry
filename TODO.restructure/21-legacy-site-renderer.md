# 21 — Legacy `lib/g18/site/` appears unused by CI

## Context
- `lib/g18/site.rb` + `lib/g18/site/renderer.rb` define a static site
  renderer (`G18::Site::Renderer`) that builds HTML via ERB templates.
- `scripts/build_site.rb` invokes it.
- BUT: the CI deploy workflow (`.github/workflows/deploy.yml`) does
  NOT call `build_site.rb`. The frontend is built via Astro (`pnpm build`).
- The site is now served from `web/dist/`, not `_site/`.

The entire `lib/g18/site/` namespace looks like dead code from before
the Astro migration.

## Plan
1. Verify no external tooling references `G18::Site::Renderer`
2. If truly unused: remove `lib/g18/site/`, `lib/g18/site.rb`,
   `scripts/build_site.rb`, and any `templates/` directory
3. If uncertain: leave in place but add a deprecation comment

## Risk
Per the user's strict global rules ("NEVER DELETE any file you did not
create"), do NOT delete without explicit user approval. Surface as a
question.

## Out of scope
This is a "should we delete?" question, not a refactor. Requires user
judgment.
