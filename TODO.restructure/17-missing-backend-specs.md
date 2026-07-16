# 17 — Add missing backend specs

## Context
After the export modularization, these modules lack specs:
- `G18::Export::ConceptDiffer`
- `G18::Export::SourcedFromEnricher`
- `G18::Export::TermProcessor` (integration)
- `G18::Export::Pipeline` (end-to-end smoke test)

## Plan
- spec/export/concept_differ_spec.rb — tempdir fixtures, verify diff output shape
- spec/export/sourced_from_enricher_spec.rb — tempdir fixtures with raw YAML
- spec/export/term_processor_spec.rb — small fixture set, verify enriched hash shape
- spec/export/pipeline_spec.rb — uses real vocab repo (skip if absent), verifies file outputs

## Why
These modules have branching logic and tempdir-based fixtures provide fast, deterministic tests.
