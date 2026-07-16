# frozen_string_literal: true

# G 18 export pipeline — turns per-term YAML under data/ into the JSON
# consumed by the Vue frontend.
#
# Modules:
#   - Renderer            — pure: renders stem:[...] → MathML
#   - Matcher             — pure: 5-case alignment classification
#   - GlossaristBridge    — Node.js bridge to glossarist-js (cached)
#   - ConceptDiffer       — computes edition-pair diffs via glossarist-js
#   - PublicationEnricher — bib load + relaton TC/SC + lifecycle
#   - TermProcessor       — per-term YAML → enriched term hash
#   - SourcedFromEnricher — adds sourced_from from raw vocab YAML
#   - Deduplicator        — pure: dedup pub instances by (pub_id, clause)
#   - DataFixups          — pure: applies known source-data corrections
#   - LatestDatasets      — constants: current V1/V2 edition metadata
#   - JsonWriter          — writes every output JSON file
#   - Pipeline            — orchestrator
module G18
  module Export
    DIR = File.expand_path("export", __dir__).freeze
    autoload :Renderer,              File.join(DIR, "renderer")
    autoload :Matcher,               File.join(DIR, "matcher")
    autoload :GlossaristBridge,      File.join(DIR, "glossarist_bridge")
    autoload :ConceptDiffer,         File.join(DIR, "concept_differ")
    autoload :PublicationEnricher,   File.join(DIR, "publication_enricher")
    autoload :TermProcessor,         File.join(DIR, "term_processor")
    autoload :SourcedFromEnricher,   File.join(DIR, "sourced_from_enricher")
    autoload :Deduplicator,          File.join(DIR, "deduplicator")
    autoload :DataFixups,            File.join(DIR, "data_fixups")
    autoload :LatestDatasets,        File.join(DIR, "latest_datasets")
    autoload :JsonWriter,            File.join(DIR, "json_writer")
    autoload :Pipeline,              File.join(DIR, "pipeline")
  end
end
