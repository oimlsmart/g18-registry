# G 18 — OIML Term-Usage Registry

**A usage registry, not a vocabulary.** G 18 collates the instances where a term is used across OIML Recommendations and Documents, with each instance's definition and a consistency check against the official VIM/VIML definition.

## Architecture

```
oimlsmart/vocab (read-only)
  └─ datasets/
        ├─ g18-2010/        ← published edition (2125 concepts)
        ├─ g18-202X/        ← draft edition being validated (2813 concepts)
        └─ vim-*/viml-*/    ← VIM/VIML authoritative definitions
              │
              │ Ruby migration (scripts/migrate_from_vocab.rb)
              ▼
g18-registry (this repo)
  ├─ data/                  ← per-term YAML (committed; migration output)
  ├─ web/                   ← Vue 3 + vite-ssg frontend
  │   ├─ src/
  │   │   ├─ types/model.ts         ← TypeScript types
  │   │   ├─ composables/           ← shared logic (useVocabularyEdition)
  │   │   ├─ styles/                ← tokens.css, global.css, components.css
  │   │   ├─ pages/                 ← 11 pages (index, terms, editions, etc.)
  │   │   └─ data/*.json            ← exported from Ruby (committed)
  │   └── vite.config.ts
  ├─ lib/g18/               ← Ruby domain model + migration logic
  ├─ scripts/
  │   ├─ migrate_from_vocab.rb      ← vocab → data/ (run locally)
  │   ├─ export_for_vite.rb         ← data/ → web/src/data/*.json
  │   ├─ check_consistency.rb       ← LLM-based classification (run locally)
  │   └── build_site.rb             ← ERB site (legacy, being phased out)
  └─ tc-sc/                 ← bibliography + TC/SC attribution
```

## Editor workflow (local → commit → CI deploys)

```bash
# 1. Rebuild data/ from vocab datasets (both editions + VIM/VIML enrichment)
ruby scripts/migrate_from_vocab.rb

# 2. Export data/ to JSON for the Vue frontend
ruby scripts/export_for_vite.rb

# 3. Run AI consistency check (requires LLM API key)
source ~/.zai-api-key
ruby scripts/check_consistency.rb --run --base-url https://api.z.ai/api/anthropic --model glm-5.2 --api-key "$Z_AI_API_KEY"

# 4. Re-export after consistency (applies results to JSON)
ruby scripts/export_for_vite.rb

# 5. Build and preview the Vue site
cd web && pnpm install && pnpm run build
cd .. && python3 -m http.server -d web/dist 8000

# 6. Commit data/ + web/src/data/ with results baked in
git add data/ web/src/data/
git commit -m "data: refresh + consistency + latest_check"
```

## Deployment

GitHub Pages via `.github/workflows/deploy.yml`. On push to `main`:
1. `pnpm install` in `web/`
2. `pnpm run build` (vite-ssg prerenders all routes)
3. Upload `web/dist/` as Pages artifact

**No Ruby, no LLM, no migration in CI** — the committed `web/src/data/*.json` is the deployable snapshot.

## Tech stack

| Layer | Technology |
|---|---|
| Data pipeline | Ruby (stdlib only — YAML, JSON, Net::HTTP) |
| Static site | Vue 3 + vite-ssg (prerendered to static HTML) |
| Consistency check | LLM (Z.AI GLM-5.2 via Anthropic-compatible API) |
| Deploy | GitHub Actions + GitHub Pages |
| Source data | [oimlsmart/vocab](https://github.com/oimlsmart/vocab) |
