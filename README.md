# G 18 — OIML Term-Usage Registry

**A usage registry, not a vocabulary.** G 18 collates the instances where a term is used across OIML Recommendations and Documents, with each instance's definition and a consistency check against the official VIM/VIML definition.

## Why a separate project

G 18 is structurally different from VIM/VIML:

- **VIM/VIML** = *authoritative concept definitions* (the source of truth)
- **G 18** = *observation registry* (where terms appear, with what definition)

The canonical data lives in [`oimlsmart/vocab` `datasets/g18/`](https://github.com/oimlsmart/vocab/tree/main/datasets/g18/) (2132 entries). This repo consumes that data and renders it as a term-usage registry, separate from the vocab concept-browser.

## Use cases (per OIML TC 1 / Vocabularies)

- **TC editor**: identify which terms in your Recommendation diverge from the official VIM/VIML definition.
- **TC chair**: see which TC/SC has the most drift from official vocabulary.
- **Authoring a new Recommendation**: search for a term; if it's in VIM/VIML, get the official definition; if it's already in G 18 from other Recs, see how others defined it; pick the most authoritative.
- **OIML secretariat**: maintain a consistency dashboard across all Recommendations.

## Status

The registry is live. See [`migration-report.md`](migration-report.md) for current counts and invariant checks.

| # | Title | Status |
|---|---|---|
| 02 | [Convert `datasets/g18/` to per-term model](TODO/02-migrate-per-term-model.md) | done — 1203 unique-term files in `data/`, 2132 instances preserved |
| 03 | [TC/SC → publication map](TODO/03-tc-sc-publication-map.md) | scaffold in `tc-sc/publications.yaml`; 1/88 attributed, awaiting OIML confirmation |
| 04 | [Browsing UI](TODO/04-browsing-ui.md) | done — `scripts/build_site.rb` renders `_site/` |
| 05 | [AI consistency check](TODO/05-ai-consistency-check.md) | harness in `scripts/check_consistency.rb`; run on demand with `--run --api-key ...` |
| 06 | [Initial deployment](TODO/06-initial-deployment.md) | done — `.github/workflows/deploy.yml` builds and deploys via Pages |

Step 1 (removing G 18 from the vocab concept-browser) was done in [`oimlsmart/vocab#41`](https://github.com/oimlsmart/vocab/pull/41). The G 18 *data* remains in that repo as the canonical source.

## Architecture

```
oimlsmart/vocab         (existing, read-only)
  └─ datasets/
        ├─ g18-2010/      ← published edition (2125 concepts)
        ├─ g18-202X/      ← draft edition being validated (2813 concepts)
        ├─ vim-1993/ ... vim-2012/   ← VIM editions (authoritative baseline)
        └─ viml-1968/ ... viml-2022/ ← VIML editions
              │
              │ consumed by scripts/migrate_from_vocab.rb (run locally)
              ▼
oimlsmart/g18-registry  (this repo)
  ├─ TODO/                ← step-by-step plan (historical)
  ├─ data/                ← COMMITTED: per-term YAML with edition tags,
  │                         VIM/VIML enrichment, and consistency results
  ├─ tc-sc/
  │   ├─ publications.yaml     ← bibliography + TC/SC attribution
  │   └─ term-aliases.yaml     ← editorial merges (singular/plural, etc.)
  ├─ lib/g18/             ← migration, site, consistency logic
  ├─ scripts/
  │   ├─ migrate_from_vocab.rb   ← vocab → data/ (run locally, commit result)
  │   ├─ build_site.rb           ← data/ → _site/ (runs in CI)
  │   ├─ check_consistency.rb    ← LLM-based classification (run locally, commit result)
  │   ├─ sync_tc_sc.rb           ← pull bibliography updates from vocab
  │   └─ validate_tc_sc.rb       ← integrity check for tc-sc/
  ├─ templates/           ← ERB templates for the static site
  ├─ static/              ← CSS + OIML logos
  ├─ _site/               ← rendered site (gitignored; built by build_site.rb)
  └─ cache/               ← consistency cache (gitignored; rebuilds as needed)
```

## Editor workflow (local → commit → CI deploys)

The CI workflow only builds the site from the committed `data/`. Editors
must run migration and consistency check locally and commit the results.

```bash
# 1. Rebuild data/ from ../vocab/datasets/g18-{2010,202X} with VIM/VIML enrichment
ruby scripts/migrate_from_vocab.rb

# 2. Run the AI consistency check (requires LLM API key)
source ~/.zai-api-key   # or: export ANTHROPIC_API_KEY=...
ruby scripts/check_consistency.rb \
  --run \
  --base-url https://api.z.ai/api/anthropic \
  --model glm-5.2 \
  --api-key "$Z_AI_API_KEY"

# 3. Rebuild the site locally to verify
ruby scripts/build_site.rb
open _site/index.html

# 4. Commit data/ with the new consistency values baked in
git add data/ migration-report.md
git commit -m "data: refresh from <edition> + consistency results"
```

## When G 18 is updated upstream

When `oimlsmart/vocab` ships a new edition of G 18 (e.g., a 202X revision,
a new published edition, or simply more concepts added to an existing
edition), refresh the registry:

### 1. Pull the vocab repo

```bash
cd ../vocab
git pull origin main
cd -
```

### 2. Make sure `scripts/migrate_from_vocab.rb` knows about the new edition

The script's default `--editions` list is hard-coded in
`scripts/migrate_from_vocab.rb` (search for `options[:editions]`). Add a
new entry there for any brand-new edition, e.g.:

```ruby
options[:editions] = [
  { name: "202X", path: File.join(v, "g18-202X"), primary: true },
  { name: "2030", path: File.join(v, "g18-2030"), primary: true },  # ← new
  { name: "2010", path: File.join(v, "g18-2010"), primary: false },
]
```

Only one edition should have `primary: true` (the one TC 1 is currently
validating). Convention: the newest draft is primary; older editions are
secondary (kept for historical comparison).

### 3. Refresh `data/`

```bash
ruby scripts/migrate_from_vocab.rb
```

The migration reads every concept in every configured edition dir, tags
each instance with its `edition`, groups by canonicalized designation,
and writes per-term YAML files into `data/`. Existing files are
overwritten (the migration does `FileUtils.rm_rf("data")` first).

### 4. Re-run the AI consistency check

```bash
source ~/.zai-api_key   # or: export ANTHROPIC_API_KEY=...
ruby scripts/check_consistency.rb \
  --run \
  --base-url https://api.z.ai/api/anthropic \
  --model glm-5.2 \
  --api-key "$Z_AI_API_KEY"
```

The cache (`cache/consistency.jsonl`) is keyed by hash of
(official_definition, publication_definition). Already-cached entries are
skipped, so only new or changed publications trigger LLM calls. Typical
cost: a few cents per run after the initial population.

### 5. Rebuild the site locally and verify

```bash
ruby scripts/build_site.rb
open _site/index.html
```

Spot-check the index page stats, the editions comparison page, and a few
per-term pages (especially the new edition's terms-only page).

### 6. Commit the snapshot

```bash
git add data/ migration-report.md
git commit -m "data: refresh after <edition> update

- <edition>: <N> source concepts (<delta> vs previous)
- <M> new harmonisation candidates
- consistency: <X> ok / <Y> partial / <Z> ko"
```

Push to a feature branch and open a PR. After merge to `main`, the CI
workflow rebuilds the site from the committed `data/` and deploys — no
LLM calls happen in CI.

## Deployment

GitHub Pages via [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml).
On every push to `main`, the workflow runs `scripts/build_site.rb` against
the committed `data/` and deploys `_site/`. **No LLM calls and no migration
happen in CI** — editors run those locally and commit the snapshot.

## Related

- Issue: [oimlsmart/vocab#42 — G 18 future direction](https://github.com/oimlsmart/vocab/issues/42)
- Source data (published): [`oimlsmart/vocab` `datasets/g18-2010/`](https://github.com/oimlsmart/vocab/tree/main/datasets/g18-2010/)
- Source data (draft): [`oimlsmart/vocab` `datasets/g18-202X/`](https://github.com/oimlsmart/vocab/tree/main/datasets/g18-202X/)
