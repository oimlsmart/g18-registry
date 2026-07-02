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
  └─ datasets/g18/        ← canonical source data, NOT to be deleted
        │
        │ consumed by scripts/migrate_from_vocab.rb
        ▼
oimlsmart/g18-registry  (this repo)
  ├─ TODO/                ← step-by-step plan (historical)
  ├─ data/                ← per-term model: one YAML per unique term
  ├─ tc-sc/
  │   ├─ publications.yaml     ← bibliography + TC/SC attribution
  │   └─ term-aliases.yaml     ← editorial merges (singular/plural, etc.)
  ├─ lib/g18/             ← migration, site, consistency logic
  ├─ scripts/
  │   ├─ migrate_from_vocab.rb   ← vocab → data/ (run on source changes)
  │   ├─ build_site.rb           ← data/ → _site/ (run on every deploy)
  │   ├─ check_consistency.rb    ← LLM-based consistency classification (TODO 05)
  │   ├─ sync_tc_sc.rb           ← pull bibliography updates from vocab
  │   └─ validate_tc_sc.rb       ← integrity check for tc-sc/
  ├─ templates/           ← ERB templates for the static site
  ├─ static/              ← CSS and other static assets
  ├─ _site/               ← rendered site (gitignored; built by build_site.rb)
  └─ cache/               ← consistency cache (gitignored)
```

URN cross-references to VIM/VIML stay the same: `urn:oiml:pub:v:1:2022`, `urn:oiml:pub:v:2:1993`, etc. G 18 entries link to VIM/VIML via `related: - type: see` edges.

## Local development

```bash
# Rebuild data/ from ../vocab/datasets/g18 (run when aliases or source data change)
ruby scripts/migrate_from_vocab.rb

# Rebuild the static site into _site/
ruby scripts/build_site.rb

# Open the registry locally
open _site/index.html

# (Optional) Run consistency check in dry-run mode
ruby scripts/check_consistency.rb
```

The migration reads the sibling `oimlsmart/vocab` checkout at `../vocab/datasets/g18`. Set `VOCAB_G18_DIR` to point elsewhere.

## Deployment

GitHub Pages via [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml). On every push to `main`, the workflow runs `scripts/build_site.rb` and deploys `_site/`. The committed `data/` is the source of truth for the build — migration is run locally when editors pull new vocab data or extend `tc-sc/term-aliases.yaml`.

## Related

- Issue: [oimlsmart/vocab#42 — G 18 future direction](https://github.com/oimlsmart/vocab/issues/42)
- Source data: [`oimlsmart/vocab` `datasets/g18/`](https://github.com/oimlsmart/vocab/tree/main/datasets/g18/)
