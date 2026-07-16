#!/usr/bin/env ruby
# frozen_string_literal: true

# Export per-term YAML data and bibliography into JSON for the Vite + Vue
# frontend. Reads from `data/` (migrated from vocab repo) and vocab repo
# bibliographies + relaton-data-oiml (for TC/SC enrichment), writes
# one JSON file per entity into `web/src/data/`.
#
# Also builds a "latest edition check" for every term whose official_concept
# references a superseded VIM/VIML edition: looks up the term's designation
# in the latest edition's concept files and embeds the result so the UI can
# show definitively whether the term is current, rather than asking the user
# to "verify".
#
# Usage:
#   scripts/export_for_vite.rb [--data-dir DIR] [--out-dir DIR] [--vocab-root DIR]
#
# Defaults: data/ and web/src/data/ relative to repo root.

require "optparse"
require "yaml"
require "json"
require "fileutils"
require "open3"
require_relative "../lib/g18"

# Plurimath for AsciiMath → MathML pre-rendering of stem:[...] content.
# The JS package (@plurimath/plurimath) has broken dist; the Ruby gem
# produces identical MathML at export time.
begin
  require "plurimath"
  PLURIMATH_AVAILABLE = true
rescue LoadError
  PLURIMATH_AVAILABLE = false
  warn "WARNING: plurimath gem not loaded — stem:[] will render as <code>."
end

# Convert stem:[<asciimath>] → inline MathML in any text string.
# Falls back to <code>stem:[...]</code> if Plurimath fails on an expression.
def render_stem(text)
  return text unless text.is_a?(String) && text.include?("stem:[")
  text.gsub(/stem:\[([^\]]+)\]/) do
    expr = $1
    if PLURIMATH_AVAILABLE
      begin
        mathml = Plurimath::Math.parse(expr, :asciimath).to_mathml
        # Force inline display mode (default is block).
        mathml.sub('display="block"', 'display="inline"')
      rescue StandardError => e
        "<code>stem:[#{expr}]</code>"
      end
    else
      "<code>stem:[#{expr}]</code>"
    end
  end
end

# Recursively render stem:[] in any hash/array/string structure.
def render_stem_deep(obj)
  case obj
  when String then render_stem(obj)
  when Hash   then obj.transform_values { |v| render_stem_deep(v) }
  when Array  then obj.map { |v| render_stem_deep(v) }
  else obj
  end
end

repo_root = File.expand_path("..", __dir__)
default_vocab_root = File.expand_path("vocab/datasets", File.join(repo_root, ".."))
options = {
  data_dir: File.join(repo_root, "data"),
  out_dir: File.join(repo_root, "web", "src", "data"),
  vocab_root: ENV.fetch("VOCAB_ROOT", default_vocab_root),
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--data-dir DIR", String) { |v| options[:data_dir] = v }
  opts.on("--out-dir DIR", String) { |v| options[:out_dir] = v }
  opts.on("--vocab-root DIR", String) { |v| options[:vocab_root] = v }
end.parse!

FileUtils.mkdir_p(options[:out_dir])

# ── Build latest-edition designation index (via glossarist-js) ───────────
# Uses glossarist-js to parse concept YAML files properly, instead of
# hand-rolling YAML parsing. Loads ALL concept data once per dataset and
# caches it for both the designation index and concept detail lookups.

LATEST_DATASETS = {
  vim:  { urn: G18::Vocabulary::LATEST_VIM_URN,  dir: "vim-2012",  label: "VIM 2012" },
  viml: { urn: G18::Vocabulary::LATEST_VIML_URN, dir: "viml-2022", label: "VIML 2022" },
}.freeze

glossarist_script = File.expand_path("../web/scripts", __dir__)

def load_concept_index_via_glossarist(script_dir, concepts_dir)
  return [{}, {}] unless Dir.exist?(concepts_dir)
  stdout, status = Open3.capture2("node", "#{script_dir}/load-vocab-concepts.mjs", concepts_dir, "full")
  return [{}, {}] unless status.success?
  full = JSON.parse(stdout)
  # Build designation index from full data
  idx = {}
  full.each do |id, langs|
    eng = langs["eng"] || langs.values&.first
    next unless eng
    pref = (eng["designations"] || []).find { |d| d["status"] == "preferred" } || (eng["designations"] || [])&.first
    next unless pref&.dig("text")
    defn = (eng["definitions"] || []).join("\n").strip
    idx[pref["text"].downcase.strip] = { id: id, definition: defn }
  end
  [idx, full]
rescue JSON::ParserError, StandardError
  [{}, {}]
end

# Cache for cited-edition concept data (loaded lazily per dataset dir).
$cited_concept_cache = {}

def cached_concept_lookup(script_dir, vocab_root, dataset_dir, concept_id)
  cache_key = dataset_dir
  unless $cited_concept_cache.key?(cache_key)
    concepts_dir = File.join(vocab_root, dataset_dir, "concepts")
    if Dir.exist?(concepts_dir)
      stdout, status = Open3.capture2("node", "#{script_dir}/load-vocab-concepts.mjs", concepts_dir, "full")
      $cited_concept_cache[cache_key] = status.success? ? JSON.parse(stdout) : {}
    else
      $cited_concept_cache[cache_key] = {}
    end
  end
  $cited_concept_cache[cache_key][concept_id]
rescue StandardError
  nil
end

require "open3"

latest_indices = {}
latest_full_concepts = {}
LATEST_DATASETS.each do |vocab, info|
  concepts_dir = File.join(options[:vocab_root], info[:dir], "concepts")
  if Dir.exist?(concepts_dir)
    idx, full = load_concept_index_via_glossarist(glossarist_script, concepts_dir)
    latest_indices[vocab] = idx
    latest_full_concepts[vocab] = full
    warn "  Latest #{info[:label]}: #{idx.size} designations indexed (via glossarist-js)"
  else
    warn "  Latest #{info[:label]}: concepts dir not found at #{concepts_dir} — latest_check will be skipped"
  end
end

# ── Pre-compute concept diffs between editions (via glossarist-js) ────────
# For each vocabulary, diff each historical edition against the latest so
# the term detail page can show "what changed" in the concept version series.
concept_diffs = {}
diff_script = File.expand_path("../web/scripts/compute-concept-diffs.mjs", __dir__)
DIFF_PAIRS = {
  vim: [["vim-1993", "vim-2012"], ["vim-2007", "vim-2012"], ["vim-2010", "vim-2012"]],
  viml: [["viml-2000", "viml-2022"], ["viml-2013", "viml-2022"]],
}.freeze
DIFF_PAIRS.each do |_vocab, pairs|
  pairs.each do |old_dir, new_dir|
    old_path = File.join(options[:vocab_root], old_dir, "concepts")
    new_path = File.join(options[:vocab_root], new_dir, "concepts")
    next unless Dir.exist?(old_path) && Dir.exist?(new_path)
    diff_key = "#{old_dir}->#{new_dir}"
    stdout, status = Open3.capture2("node", diff_script, old_path, new_path)
    if status.success?
      concept_diffs[diff_key] = JSON.parse(stdout)
      warn "  Concept diffs #{old_dir} → #{new_dir}: #{concept_diffs[diff_key].size} concepts changed"
    end
  rescue StandardError => e
    warn "  WARNING: concept diff #{diff_key} failed: #{e.message}"
  end
end

def check_latest_edition(term_name, official_urn, concept_id, latest_indices)
  return nil unless official_urn && term_name
  vocab = G18::Vocabulary.vocab(official_urn)
  return nil unless vocab
  info = LATEST_DATASETS[vocab]
  return nil unless info
  idx = latest_indices[vocab]
  return nil unless idx&.any?
  lookup = term_name.to_s.downcase.strip

  # 1. Exact name match
  entry = idx[lookup]

  # 2. Concept-ID match (handles designation changes across editions,
  #    e.g. "adjustment" in VIM 2007 → "adjustment of a measuring system"
  #    in VIM 2012, same concept #3.11)
  entry ||= idx.values.find { |v| v[:id] == concept_id } if concept_id

  # 3. Fuzzy match (handles concept renumbering + designation changes)
  entry ||= (m = G18::FuzzyMatch.match(term_name, idx); m ? m[:entry] : nil)

  if entry
    {
      "found" => true,
      "vocab" => vocab.to_s,
      "latest_label" => info[:label],
      "latest_urn" => info[:urn],
      "concept_id" => entry[:id],
      "definition" => entry[:definition],
      "url" => "https://www.oimlsmart.org/vocab/dataset/#{info[:dir]}/concept/#{entry[:id]}",
    }
  else
    {
      "found" => false,
      "vocab" => vocab.to_s,
      "latest_label" => info[:label],
      "latest_urn" => info[:urn],
    }
  end
end

# Token-overlap similarity (Jaccard) for fuzzy term-name matching.
# Check term presence across BOTH vocab indices (used for OIML-original
# terms that don't have an `official_concept` URN). Returns near-miss
# candidates for both vocabularies so the gap-analysis page can suggest
# Propose-for-VIM / Propose-for-VIML / Propose-for-V3.
def normalize_definition(text)
  return "" unless text
  text.to_s.gsub(/\{\{[^}]+\}\}/, "").gsub(/[^a-z0-9\s]/i, " ").split.join(" ").downcase.strip
end

def classify_alignment(term_name, term_definition, latest_indices, latest_full_concepts = {})
  result = { "vim" => nil, "viml" => nil, "case" => 5, "alignment" => "none" }
  return result unless term_name
  best_case = 5
  best_match = nil
  %w[vim viml].each do |vocab|
    idx = latest_indices[vocab.to_sym] || latest_indices[vocab]
    next unless idx&.any?
    full = latest_full_concepts[vocab.to_sym] || latest_full_concepts[vocab] || {}
    lookup = term_name.to_s.downcase.strip
    norm_def = normalize_definition(term_definition)

    if idx.key?(lookup)
      info = LATEST_DATASETS[vocab.to_sym]
      entry = idx[lookup]
      full_concept = full[entry[:id]]
      match = build_vocab_match(entry, full_concept, info, term_name, "exact")
      vocab_def = normalize_definition(entry[:definition])
      if vocab_def == norm_def && !vocab_def.empty?
        match["alignment"] = "aligned"
        c = 1
      else
        match["alignment"] = "diverges"
        match["oiml_definition"] = term_definition
        c = 3
      end
      result[vocab] = match
      if c < best_case
        best_case = c
        best_match = vocab
      end
    else
      m = G18::FuzzyMatch.match(term_name, idx)
      if m
        info = LATEST_DATASETS[vocab.to_sym]
        full_concept = full[m[:entry][:id]]
        match = build_vocab_match(m[:entry], full_concept, info, m[:designation], "fuzzy", m[:similarity])
        match["alignment"] = "fuzzy"
        if 4 < best_case
          best_case = 4
          best_match = vocab
        end
        result[vocab] = match
      end
    end
  end
  result["case"] = best_case
  result["alignment"] = case best_case
    when 1 then "aligned"
    when 3 then "diverges"
    when 4 then "fuzzy"
    else "none"
  end
  result["matched_vocab"] = best_match
  result
end

# Legacy alias — kept for backward compat with existing call sites
def check_vocab_presence(term_name, latest_indices, latest_full_concepts = {})
  result = classify_alignment(term_name, nil, latest_indices, latest_full_concepts)
  { "vim" => result["vim"], "viml" => result["viml"] }
end

def build_vocab_match(entry, full_concept, info, designation, match_type, similarity = nil)
  eng = full_concept&.dig("eng") || full_concept&.values&.first
  match = {
    "found" => match_type == "exact",
    "match_type" => match_type,
    "designation" => designation,
    "concept_id" => entry[:id],
    "definition" => entry[:definition],
    "latest_label" => info[:label],
    "url" => "https://www.oimlsmart.org/vocab/dataset/#{info[:dir]}/concept/#{entry[:id]}",
  }
  match["similarity"] = similarity.round(3) if similarity
  if eng
    match["notes"] = eng["notes"] || []
    match["examples"] = eng["examples"] || []
    match["designations"] = eng["designations"] || []
  end
  match
end

# ── Publications ──────────────────────────────────────────────────────────
# Read from the authoritative vocab repo bibliographies (no local copy).
# Merge g18-202X + g18-2010, dedup by ID. Enrich TC/SC from relaton-data-oiml.
vocab_bib_files = [
  File.join(options[:vocab_root], "oiml-complete", "bibliography.yaml"),
  File.join(options[:vocab_root], "g18-202X", "bibliography.yaml"),
  File.join(options[:vocab_root], "g18-2010", "bibliography.yaml"),
].select { |f| File.exist?(f) }

publications = []
vocab_bib_files.each do |path|
  docs = YAML.safe_load(File.read(path), aliases: true) || []
  docs.each do |p|
    publications << p unless publications.any? { |e| e["id"] == p["id"] }
  end
end

# Enrich TC/SC from relaton-data-oiml (authoritative bibliographic source)
relaton_root = ENV.fetch("RELATON_ROOT",
  File.expand_path("../../relaton/relaton-data-oiml", repo_root))
relaton_index_path = File.join(relaton_root, "index-v2.yaml")

if File.exist?(relaton_index_path)
  relaton_index = YAML.load_file(relaton_index_path, aliases: true) || []

  # Convert v2 structured PubID to OIML string ID (e.g. "OIML R 60:2021")
  pubid_type_prefix = {
    "pubid:oiml:basic-publication" => "B",
    "pubid:oiml:recommendation" => "R",
    "pubid:oiml:document" => "D",
    "pubid:oiml:international-document" => "D",
  }
  convert_pubid = lambda do |id|
    if id.is_a?(String)
      id
    elsif id["_type"] == "pubid:oiml:amendment"
      base = convert_pubid.call(id["base_identifier"])
      "#{base}+Amendment:#{id['year']}"
    else
      letter = pubid_type_prefix[id["_type"]]
      return nil unless letter
      s = "#{id['publisher']} #{letter} #{id['number']}"
      s += "-#{id['part']}" if id["part"]
      s += ":#{id['year']}" if id["year"]
      s += " (#{id['language']})" if id["language"]
      s
    end
  end

  # Build OIML ID → relaton file path map (skip language-suffixed entries)
  relaton_file_map = {}
  relaton_index.each do |entry|
    raw_id = entry[:id] || entry["id"]
    file = entry[:file] || entry["file"]
    next if raw_id.nil? || file.nil?
    id_str = convert_pubid.call(raw_id)
    next if id_str.nil?
    next if id_str =~ /\s\([EF]\)\s*$/
    relaton_file_map[id_str] = File.join(relaton_root, file.to_s)
  end

  publications.each do |p|
    relaton_file = relaton_file_map[p["id"]]
    next unless relaton_file && File.exist?(relaton_file)
    doc = YAML.load_file(relaton_file, aliases: true) rescue next
    tc_part = nil
    sc_part = nil
    (doc["contributor"] || []).each do |c|
      subdivisions = c.dig("organization", "subdivision") || []
      subdivisions.each do |sub|
        identifiers = sub["identifier"] || []
        content = identifiers.map { |i| i["content"] }.compact.first
        next unless content
        case sub["type"]
        when "technical-committee" then tc_part ||= content
        when "subcommittee" then sc_part ||= content
        end
      end
    end
    parts = [tc_part, sc_part].compact
    p["tc_sc"] = parts.join("/") if parts.any?
    # Extract withdrawn status
    stage = doc.dig("status", "stage")
    stage_str = stage.is_a?(Hash) ? stage["content"] : stage
    p["withdrawn"] = true if stage_str.to_s.downcase == "withdrawn"
  end
end

# ── Publication lifecycle: current vs retired vs withdrawn ────────────────
# Group publications by document family (e.g., R 49-1), find the latest
# non-withdrawn edition as "current", mark older editions as "retired".
pub_families = {}
publications.each do |p|
  id = p["id"].to_s
  m = id.match(/OIML\s+([A-Z])\s*(\d+)(?:-(\d+))?:(\d{4})/)
  next unless m
  family = "#{m[1]} #{m[2]}"
  family += "-#{m[3]}" if m[3]
  pub_families[family] ||= []
  pub_families[family] << { id: id, year: m[4].to_i, withdrawn: !!p["withdrawn"] }
end
pub_lifecycle = {}
pub_families.each do |family, editions|
  active = editions.reject { |e| e[:withdrawn] }
  current_year = active.map { |e| e[:year] }.max
  editions.each do |e|
    if e[:withdrawn]
      pub_lifecycle[e[:id]] = "withdrawn"
    elsif e[:year] == current_year
      pub_lifecycle[e[:id]] = "current"
    else
      pub_lifecycle[e[:id]] = "retired"
    end
  end
end
publications.each { |p| p["lifecycle"] = pub_lifecycle[p["id"]] || "current" }

File.write(File.join(options[:out_dir], "publications.json"),
           JSON.generate(publications))

# Build pub_id → tc_sc map for enriching term publication instances.
# The vocab repo migration produces empty tc_sc; relaton enrichment fills
# it at the publication level, and we propagate it into term instances here.
pub_tc_sc_map = {}
pub_withdrawn_set = Set.new
pub_lifecycle_map = {}
publications.each do |p|
  pub_tc_sc_map[p["id"]] = p["tc_sc"] if p["tc_sc"] && !p["tc_sc"].to_s.strip.empty?
  pub_withdrawn_set << p["id"] if p["withdrawn"]
  pub_lifecycle_map[p["id"]] = p["lifecycle"] if p["lifecycle"]
end

# ── Data fixups ──────────────────────────────────────────────────────────
# Known source-data issues corrected before export so the UI shows accurate
# provenance and definition-grouping. Each fixup is documented so it can be
# removed once the source YAML in the vocab repo is corrected.
DATA_FIXUPS = {
  # R 142-1:2025 cites V 2-200:2007 but the PDF actually references VIM 3.11
  # which is the 2012 edition. Confirmed by user review of the PDF.
  "OIML R 142-1:2025" => { ref_source: "OIML V 2-200:2012" },
  # R 99-1:2008 definition has "aquantity" (missing space) — fix to match
  # the correct "a quantity" used by the other publications.
  "OIML R 99-1:2008" => { def_fix: /aquantity/, def_replacement: "a quantity" },
}.freeze

# ── Terms ─────────────────────────────────────────────────────────────────
terms = []
vocab_gaps = []
Dir.glob(File.join(options[:data_dir], "*.yaml")).sort.each do |path|
  docs = YAML.safe_load_stream(File.read(path), aliases: true)
  next unless docs.first.is_a?(Hash)
  hash = docs.find { |d| d.is_a?(Hash) && d["data"] && d["data"]["term"] } || docs.first
  data = hash["data"] || {}
  # Propagate TC/SC from relaton-enriched publications into term instances
  (data["publications"] || []).each do |p|
    if (!p["tc_sc"] || p["tc_sc"].to_s.strip.empty?) && p["publication_id"]
      p["tc_sc"] = pub_tc_sc_map[p["publication_id"]] if pub_tc_sc_map[p["publication_id"]]
    end
    # Flag withdrawn publication instances
    (data["publications"] || []).each do |p|
      p["withdrawn"] = true if pub_withdrawn_set.include?(p["publication_id"])
      p["lifecycle"] = pub_lifecycle_map[p["publication_id"]] if pub_lifecycle_map[p["publication_id"]]
    end
  end
  # Apply data fixups (corrects known source-data errors before export)
  (data["publications"] || []).each do |p|
    fixup = DATA_FIXUPS[p["publication_id"]]
    next unless fixup
    if fixup[:ref_source] && p["source"]&.is_a?(Hash)
      p["source"]["ref_source"] = fixup[:ref_source]
    end
    if fixup[:def_fix] && p["definition"]
      p["definition"] = p["definition"].gsub(fixup[:def_fix], fixup[:def_replacement])
    end
  end
  oc_urn = data["official_concept"]&.dig("source")
  # Compute vocab_presence (exact + fuzzy match) for OIML-original terms
  # so the compiler can enrich action descriptions with near-miss guidance.
  # Backward compat: accept legacy "undefined" value too.
  is_oiml_original = data["kind"] == "oiml_original" || data["kind"] == "undefined"
  # Use classify_alignment for all terms — it compares designation AND definition
  first_def = (data["publications"] || []).map { |p| p["definition"] }.compact.first
  alignment_result = data["term"] ?
    classify_alignment(data["term"], first_def, latest_indices, latest_full_concepts) : nil
  vocab_presence = is_oiml_original ?
    { "vim" => alignment_result&.dig("vim"), "viml" => alignment_result&.dig("viml") } : nil
  alignment = alignment_result&.slice("case", "alignment", "matched_vocab") || nil
  # Collect vocab gap data during the main scan (avoids a second pass).
  if is_oiml_original && data["term"]
    gap_pubs = (data["publications"] || []).map do |p|
      { "publication_id" => p["publication_id"], "tc_sc" => p["tc_sc"], "edition" => p["edition"] }
    end
    gap_defs = (data["publications"] || []).map { |p| p["definition"] }.compact.uniq
    vocab_gaps << {
      "slug" => File.basename(path, ".yaml"),
      "name" => render_stem(data["term"]),
      "identifier" => data["identifier"],
      "definitions" => gap_defs,
      "publications" => gap_pubs,
      "editions_present" => data["editions_present"],
      "near_misses" => vocab_presence || { "vim" => nil, "viml" => nil },
    }
  end
  oc_id = data["official_concept"]&.dig("id")
  latest = oc_urn ? check_latest_edition(data["term"], oc_urn, oc_id, latest_indices) : nil
  # For defined terms whose latest_check found nothing, run a fuzzy match
  # against the same vocab to surface rename candidates. This drives the
  # "VIML term is 'X'" guidance on the `removed` action description.
  canonical_mismatch = nil
  if latest && !latest["found"]
    v = G18::Vocabulary.vocab(oc_urn)
    if v && latest_indices[v]&.any?
      m = G18::FuzzyMatch.match(data["term"], latest_indices[v])
      if m
        info = LATEST_DATASETS[v]
        canonical_mismatch = {
          "vocab" => v.to_s,
          "latest_label" => info[:label],
          "designation" => m[:designation],
          "concept_id" => m[:entry][:id],
          "similarity" => m[:similarity].round(3),
        }
      end
    end
  end
  # Load full VIM/VIML concept details from the vocab repo. Load BOTH
  # the cited edition (what G 18 currently references) AND the latest
  # edition (what G 18 should reference) so the term detail page can
  # show a side-by-side comparison when they differ.
  cited_concept = nil
  latest_concept = nil
  if data["official_concept"] && (oc_id = data["official_concept"]["id"])
    v = G18::Vocabulary.vocab(oc_urn)
    if oc_urn
      cited_dir = oc_urn.match(/v:[12]:(\d{4})/) do |m|
        year = m[1]
        vocab_prefix = oc_urn.include?("v:2") ? "vim" : "viml"
        "#{vocab_prefix}-#{year}"
      end
      if cited_dir
        cited_concept = cached_concept_lookup(glossarist_script, options[:vocab_root], cited_dir, oc_id)
      end
    end
    if v && (info = LATEST_DATASETS[v])
      latest_id = latest && latest["found"] ? latest["concept_id"] : oc_id
      latest_concept = (latest_full_concepts[v] || {})[latest_id]
    end
  end
  full_concept = latest_concept || cited_concept

  # Look up pre-computed concept diff (if cited and latest editions differ)
  concept_diff = nil
  if cited_dir && v && (info = LATEST_DATASETS[v])
    diff_key = "#{cited_dir}->#{info[:dir]}"
    concept_diff = concept_diffs[diff_key]&.dig(oc_id.to_s)
  end

  term = {
    "slug" => File.basename(path, ".yaml"),
    "identifier" => data["identifier"],
    "name" => render_stem(data["term"]),
    "designations" => render_stem_deep(data["designations"] || []),
    "kind" => data["kind"],
    "official_concept" => render_stem_deep(data["official_concept"])&.merge(
      "full_concept" => render_stem_deep(full_concept),
      "cited_concept" => render_stem_deep(cited_concept),
      "latest_concept" => render_stem_deep(latest_concept),
      "concept_diff" => concept_diff,
    ),
    "editions_present" => data["editions_present"],
    "primary_edition" => data["primary_edition"],
    "latest_check" => latest,
    "suggested_actions" => G18::Actions::Compiler.for_term(
      "data" => data, "latest_check" => latest,
      "vocab_presence" => vocab_presence,
      "canonical_mismatch" => canonical_mismatch,
      "alignment" => alignment
    ).map(&:to_h),
    "publications" => (data["publications"] || []).map do |p|
      render_stem_deep(p).merge(
        "defined" => data["kind"] == "defined_in_vim" || data["kind"] == "defined_in_viml",
        "official_concept" => render_stem_deep(data["official_concept"]),
        "primary_edition" => data["primary_edition"],
      )
    end,
    "related" => render_stem_deep(hash["related"] || []),
    "vocab_presence" => vocab_presence,
    "alignment" => alignment,
  }
  terms << term
end

# ── Enrich publication instances with sourced_from from raw vocab YAML ────
# glossarist can't parse concept files with lineage sources, so we read
# the raw YAML directly to extract the sourced_from chain.
%w[oiml-complete].each do |dataset|
  concepts_dir = File.join(options[:vocab_root], dataset, "concepts")
  next unless Dir.exist?(concepts_dir)
  edition = "complete"
  term_by_slug = terms.each_with_object({}) { |t, h| h[t["slug"]] = t }
  Dir.glob(File.join(concepts_dir, "*.yaml")).each do |vfile|
    begin
      vraw = File.read(vfile, encoding: "utf-8")
      vdocs = YAML.safe_load_stream(vraw, aliases: true, permitted_classes: [Date, Time])
    rescue StandardError
      next
    end
    loc_doc = vdocs.find { |d| d.is_a?(Hash) && d.dig("data", "definition") }
    next unless loc_doc
    terms_data = loc_doc.dig("data", "terms") || []
    pref = terms_data.find { |t| (t["normative_status"] || "").include?("preferred") } || terms_data.first
    next unless pref && pref["designation"]
    slug = pref["designation"].to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
    t = term_by_slug[slug]
    next unless t
    sources = Array(loc_doc.dig("data", "sources"))
    sf = []
    sources.each do |s|
      sfa = s.is_a?(Hash) ? s["sourced_from"] : nil
      next unless sfa.is_a?(Array)
      sfa.each do |ref|
        r = ref.is_a?(Hash) ? (ref["ref"] || ref) : ref
        src = r.is_a?(Hash) ? r["source"] : nil
        next unless src
        sf << { "source" => src }
      end
    end
    next if sf.empty?
    (t["publications"] || []).each do |p|
      p["sourced_from"] = sf if p["edition"] == edition && !p["sourced_from"]
    end
  end
end

File.write(File.join(options[:out_dir], "terms.json"),
           JSON.generate(terms))

# ── Per-term page data (slug → full hash) ─────────────────────────────────
by_slug = terms.each_with_object({}) { |t, h| h[t["slug"]] = t }

# ── Slim terms for list/count pages ───────────────────────────────────────
# Lightweight array with only fields needed for browsing/filtering.
# The full terms.json is ~30MB+; this slim version is ~500KB.
  terms_slim = terms.map do |t|
  pubs = t["publications"] || []
  # Deduplicate by (publication_id, clause) — same pub+clause across
  # G18 editions should count as ONE instance, not multiple.
  deduped = pubs.each_with_object({}) { |p, h| h["#{p['publication_id']}|#{p['clause']}"] ||= p }.values
  defs = deduped.map { |p| (p["definition"] || "").gsub(/\{\{[^}]+\}\}/, "").strip }.select { |d| !d.empty? }
  tc_counts = pubs.each_with_object(Hash.new(0)) { |p, h| h[p["tc_sc"]] += 1 if p["tc_sc"] && !p["tc_sc"].to_s.strip.empty? }
  {
    "slug" => t["slug"],
    "name" => t["name"],
    "kind" => t["kind"],
    "identifier" => t["identifier"],
    "editions_present" => t["editions_present"],
    "pub_count" => pubs.length,
    "pub_ids" => pubs.map { |p| p["publication_id"] }.compact.uniq,
    "tc_scs" => tc_counts.keys.sort,
    "tc_counts" => tc_counts,
    "distinct_def_count" => defs.uniq.size,
    "action_types" => (t["suggested_actions"] || []).map { |a| a["type"] },
    "designations" => t["designations"] || [],
    "official_concept_id" => t["official_concept"]&.dig("id"),
    "has_withdrawn" => pubs.any? { |p| p["withdrawn"] },
    "alignment_case" => t["alignment"]&.dig("case"),
    "alignment_status" => t["alignment"]&.dig("alignment"),
  }
end
File.write(File.join(options[:out_dir], "terms-slim.json"),
           JSON.generate(terms_slim))

# ── Fields to strip from publication instances for lighter JSON files ─────
STRIP_FROM_PUB = %w[
  source_lineage definition_paragraphs note_paragraphs example_paragraphs
  paragraph_sources note_sources example_sources annotations
  concept_sources localized_sources consistency consistency_reason
].freeze

# ── Medium terms (with slimmed publication instances) ─────────────────────
# Same as terms.json but with heavy provenance fields stripped from each
# publication instance. Used by list/analysis pages that need publication
# data (definitions, TC/SC, editions) but not source_lineage.
terms_medium = terms.map do |t|
  t.merge("publications" => (t["publications"] || []).map do |p|
    p.is_a?(Hash) ? p.reject { |k, _| STRIP_FROM_PUB.include?(k) } : p
  end)
end
File.write(File.join(options[:out_dir], "terms-medium.json"),
           JSON.generate(terms_medium))

# ── Per-term detail JSON (fetched on demand by concept pages) ─────────────
terms_detail_dir = File.join(repo_root, "web", "public", "data", "terms")
FileUtils.mkdir_p(terms_detail_dir)
terms.each do |t|
  slim_t = t.dup
  slim_t["publications"] = (t["publications"] || []).map do |p|
    p.reject { |k, _| STRIP_FROM_PUB.include?(k) }
  end
  File.write(File.join(terms_detail_dir, "#{t['slug']}.json"), JSON.generate(slim_t))
end

# ── Dashboard summary (pre-computed stats for homepage) ───────────────────
kind_counts = terms.group_by { |t| t["kind"] }.transform_values(&:count)
edition_counts = terms.each_with_object(Hash.new(0)) do |t, h|
  (t["editions_present"] || []).each { |e| h[e] += 1 }
end

# Vocabulary gap counts
gaps_viml_near_miss = vocab_gaps.count { |g| g["near_misses"]&.dig("viml") }
gaps_vim_near_miss = vocab_gaps.count { |g| g["near_misses"]&.dig("vim") }
gaps_no_match = vocab_gaps.count { |g| !g["near_misses"]&.dig("vim") && !g["near_misses"]&.dig("viml") }

# Priority worklist: top 8 non-historic terms with actions
ACTION_PRIORITY = { "upgrade_vim" => 0, "upgrade_viml" => 0, "removed" => 0,
                    "harmonize" => 1,
                    "unique" => 2, "standardize" => 2 }.freeze
priority_terms = terms
  .reject { |t| (t["editions_present"] || []) == ["2010"] }
  .select { |t| (t["suggested_actions"] || []).any? }
  .map do |t|
    actions = t["suggested_actions"] || []
    min_rank = actions.map { |a| ACTION_PRIORITY[a["type"]] || 3 }.min
    { "slug" => t["slug"], "name" => t["name"],
      "actions" => actions.first(2).map { |a| a["type"] },
      "priority_rank" => min_rank,
      "pub_count" => (t["publications"] || []).length }
  end
  .sort_by { |t| [t["priority_rank"], -t["pub_count"]] }
  .first(8)

# Publication lifecycle stats
pub_lc = pub_lifecycle.values.each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }

# Concept provenance: how many concepts come from current vs historic pubs
concepts_from_current = 0
concepts_from_historic = 0
pub_current_ids = Set.new(pub_lifecycle.select { |_, lc| lc == "current" }.keys)
pub_historic_ids = Set.new(pub_lifecycle.select { |_, lc| lc == "retired" }.keys)
pub_withdrawn_ids = Set.new(pub_lifecycle.select { |_, lc| lc == "withdrawn" }.keys)
terms.each do |t|
  pub_ids = (t["publications"] || []).map { |p| p["publication_id"] }.compact
  has_current = pub_ids.any? { |pid| pub_current_ids.include?(pid) }
  has_historic = pub_ids.any? { |pid| pub_historic_ids.include?(pid) }
  has_withdrawn = pub_ids.any? { |pid| pub_withdrawn_ids.include?(pid) }
  concepts_from_current += 1 if has_current
  concepts_from_historic += 1 if has_historic && !has_current
end

dashboard = {
  "total_terms" => terms.length,
  "total_publications" => publications.length,
  "kind_counts" => kind_counts,
  "edition_counts" => edition_counts,
  "gaps_viml_near_miss" => gaps_viml_near_miss,
  "gaps_vim_near_miss" => gaps_vim_near_miss,
  "gaps_no_match" => gaps_no_match,
  "priority_terms" => priority_terms,
  "pub_current" => pub_lc["current"] || 0,
  "pub_retired" => pub_lc["retired"] || 0,
  "pub_withdrawn" => pub_lc["withdrawn"] || 0,
  "concepts_from_current" => concepts_from_current,
  "concepts_from_historic" => concepts_from_historic,
  "alignment_counts" => terms.each_with_object(Hash.new(0)) { |t, h|
    status = t["alignment"]&.dig("alignment") || "none"
    h[status] += 1
  },
}
File.write(File.join(options[:out_dir], "dashboard.json"),
           JSON.generate(dashboard))

# ── TC/SC list ────────────────────────────────────────────────────────────
tc_set = Set.new
publications.each do |p|
  tc_set << p["tc_sc"] if p["tc_sc"] && !p["tc_sc"].to_s.strip.empty?
end
File.write(File.join(options[:out_dir], "tc.json"),
           JSON.generate(tc_set.sort))

# ── Edition stats ─────────────────────────────────────────────────────────
edition_names = terms.flat_map { |t| t["editions_present"] || [] }.uniq.sort
edition_stats = edition_names.map do |ed|
  instances = terms.sum { |t| (t["publications"] || []).count { |p| p["edition"] == ed } }
  terms_in_ed = terms.count { |t| (t["editions_present"] || []).include?(ed) }
  only_in_ed = terms.count { |t| t["editions_present"] == [ed] }
  # Harmonisation candidates: terms with ≥ 2 distinct source publications
  # in this edition.
  har = terms.count do |t|
    pubs = (t["publications"] || []).select { |p| p["edition"] == ed }
    pubs.map { |p| p["publication_id"] }.compact.uniq.size > 1
  end
  {
    "edition" => ed,
    "primary" => ed == (terms.find { |t| t["primary_edition"] } || {})["primary_edition"],
    "instances" => instances,
    "terms" => terms_in_ed,
    "only_in_edition" => only_in_ed,
    "harmonization_candidates" => har,
  }
end
File.write(File.join(options[:out_dir], "edition-stats.json"),
           JSON.generate("editions" => edition_names,
                         "stats" => edition_stats,
                         "terms_in_both" => terms.count { |t| (t["editions_present"] || []).size > 1 }))

# ── Harmonization candidates ─────────────────────────────────────────────
candidates = terms.select do |t|
  (t["publications"] || []).map { |p| p["publication_id"] }.compact.uniq.size > 1
end.sort_by { |t| -(t["publications"] || []).size }
File.write(File.join(options[:out_dir], "harmonization.json"),
           JSON.generate(candidates))

# ── ID conflicts (raw + designation collisions) ──────────────────────────
# Two DISTINCT problems:
#   1. Raw ID conflicts: same G 18 ID number assigned to DIFFERENT concepts
#      (a numbering error in the source publication). Detection must be
#      CROSS-TERM. Two disambiguation conventions appear in the dataset:
#        a/b suffix:    "00474a" vs "00474b"            (2010)
#        -RXXX-N suffix: "02344-R049-1" vs "02344-R099-1" (202X)
#      Both yield the same base "00474" / "02344" which the detector
#      recovers before comparing.
#   2. Designation collisions: same concept (designation) appearing under
#      MULTIPLE distinct IDs (each OIML publication gets its own entry).
#      This is the harmonisation worklist, not an error.

# Build GLOBAL indices across ALL terms (not per-term).
global_by_base = Hash.new { |h, k| h[k] = [] }      # base_id → [{designation, source, raw_id, edition}]
global_by_name = Hash.new { |h, k| h[k] = [] }      # designation → [{id, source, edition}]

terms.each do |t|
  (t["publications"] || []).each do |p|
    ed = p["edition"] || "—"
    id = p["g18_entry"]
    next unless id
    designation = t["name"]
    source = p["publication_id"]

    # Recover the underlying G 18 base number by stripping whatever
    # disambiguation suffix this entry carries. Only entries that were
    # suffixed are conflict candidates; canonical IDs (no suffix) don't
    # participate (they're the "winner" of any implicit split).
    base = G18::Migration::Conflicts.base_identifier(id)
    if base != id
      global_by_base[base] << {
        designation: designation, source: source, raw_id: id, edition: ed,
      }
    end

    global_by_name[designation] << { id: id, source: source, edition: ed } if designation
  end
end

# Raw ID conflicts: base IDs that map to multiple DISTINCT designations.
raw_conflicts = {}
global_by_base.each do |base, entries|
  by_edition = entries.group_by { |e| e[:edition] }
  by_edition.each do |ed, ed_entries|
    distinct_designations = ed_entries.map { |e| e[:designation] }.uniq
    next if distinct_designations.size < 2
    (raw_conflicts[ed] ||= []) << {
      "id" => base,
      "concepts" => ed_entries.uniq { |e| e[:designation] }.map { |e|
        { "designation" => e[:designation], "source" => e[:source], "raw_id" => e[:raw_id] }
      },
    }
  end
end
raw_conflicts.transform_values! { |arr| arr.sort_by { |x| x["id"] } }

# Designation collisions: designations appearing under multiple distinct IDs.
collisions = {}
global_by_name.each do |designation, entries|
  by_edition = entries.group_by { |e| e[:edition] }
  by_edition.each do |ed, ed_entries|
    unique_ids = ed_entries.map { |e| e[:id] }.uniq
    next if unique_ids.size < 2
    (collisions[ed] ||= []) << {
      "designation" => designation,
      "ids" => unique_ids.sort,
      "count" => ed_entries.size,
    }
  end
end
collisions.transform_values! do |arr|
  arr.sort_by { |x| [-x["ids"].size, x["designation"].downcase] }
end
File.write(File.join(options[:out_dir], "conflicts.json"),
           JSON.generate("raw" => raw_conflicts,
                         "designation_collisions" => collisions))

# ── Vocabulary gap analysis (data collected during main terms loop) ──────
vocab_gaps.sort_by! do |t|
  has_match = t["near_misses"]["vim"] || t["near_misses"]["viml"]
  [has_match ? 1 : 0, -(t["publications"].size)]
end
File.write(File.join(options[:out_dir], "vocab-gaps.json"),
           JSON.generate(vocab_gaps))

puts "Exported for Vite:"
# ── Page-specific pre-computed data (lightweight JSON per page) ───────────

# ActionsPage: terms with suggested actions + retire actions for withdrawn pubs
retire_action = { "type" => "retire", "priority" => "high",
  "description" => "Concept cited in a withdrawn OIML publication. Retire from G 18:current and G 18:202X.",
  "publication_ids" => [] }
actions_data = terms.map do |t|
  actions = (t["suggested_actions"] || []).dup
  withdrawn_pubs = (t["publications"] || []).select { |p| p["withdrawn"] }.map { |p| p["publication_id"] }.compact.uniq
  if withdrawn_pubs.any?
    actions << { **retire_action, "publication_ids" => withdrawn_pubs }
  end
  next nil if actions.empty?
  { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
    "actions" => actions, "pub_count" => (t["publications"]||[]).length,
    "editions_present" => t["editions_present"],
    "has_withdrawn" => withdrawn_pubs.any? }
end.compact
File.write(File.join(options[:out_dir], "actions-data.json"), JSON.generate(actions_data))

# G18DynamicPage: all concepts with first definition
g18_dynamic = terms.map { |t|
  pubs = t["publications"] || []
  { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
    "definition" => (pubs.first || {})["definition"] || "",
    "pub_count" => pubs.length } }
File.write(File.join(options[:out_dir], "g18-dynamic.json"), JSON.generate(g18_dynamic))

# G18ReadinessPage: coverage stats
total = terms.length
with_def = terms.count { |t| (t["publications"]||[]).any? { |p| (p["definition"]||"").strip.size > 0 } }
readiness = { "total" => total, "with_definition" => with_def,
              "raw_conflicts" => raw_conflicts }
File.write(File.join(options[:out_dir], "readiness-stats.json"), JSON.generate(readiness))

# LeaderboardPage: terms sorted by pub count + distinct defs
leaderboard = terms.map { |t|
  pubs = t["publications"] || []
  deduped = pubs.each_with_object({}) { |p, h| h["#{p['publication_id']}|#{p['clause']}"] ||= p }.values
  defs = deduped.map { |p| (p["definition"]||"").gsub(/\{\{[^}]+\}\}/, "").strip }.select { |d| !d.empty? }
  { "slug" => t["slug"], "name" => t["name"],
    "pub_count" => deduped.length, "distinct_defs" => defs.uniq.size,
    "editions_present" => t["editions_present"] } }
File.write(File.join(options[:out_dir], "leaderboard-data.json"), JSON.generate(leaderboard))

# PublicationsListPage: pub → term/edition stats
pub_stats = {}
terms.each do |t|
  (t["publications"] || []).each do |p|
    pid = p["publication_id"]
    next unless pid
    ed = p["edition"] || "?"
    pub_stats[pid] ||= { "editions" => Hash.new(0), "term_count" => 0, "slugs" => [] }
    pub_stats[pid]["editions"][ed] += 1
    pub_stats[pid]["term_count"] += 1
    pub_stats[pid]["slugs"] << t["slug"]
  end
end
pub_list = publications.map do |p|
  stats = pub_stats[p["id"]] || { "editions" => {}, "term_count" => 0, "slugs" => [] }
  p.merge("term_count" => stats["term_count"],
          "edition_term_counts" => stats["editions"])
end
File.write(File.join(options[:out_dir], "pub-list.json"), JSON.generate(pub_list))

# TcListPage: TC → term/pub counts per edition
tc_data = {}
terms.each do |t|
  (t["publications"] || []).each do |p|
    tc = p["tc_sc"]
    next unless tc && !tc.to_s.strip.empty?
    ed = p["edition"] || "?"
    tc_data[tc] ||= { "terms" => Set.new, "pubs" => Set.new }
    tc_data[tc]["terms"] << t["slug"]
    tc_data[tc]["pubs"] << p["publication_id"] if p["publication_id"]
    tc_data[tc]["ed_#{ed}_terms"] ||= Set.new
    tc_data[tc]["ed_#{ed}_terms"] << t["slug"]
    tc_data[tc]["ed_#{ed}_pubs"] ||= Set.new
    tc_data[tc]["ed_#{ed}_pubs"] << p["publication_id"] if p["publication_id"]
  end
end
tc_list_data = tc_data.map do |tc, d|
  { "tc" => tc, "terms_total" => d["terms"].size, "pubs_total" => d["pubs"].size,
    "terms_202X" => (d["ed_202X_terms"]||Set.new).size, "pubs_202X" => (d["ed_202X_pubs"]||Set.new).size,
    "terms_2010" => (d["ed_2010_terms"]||Set.new).size, "pubs_2010" => (d["ed_2010_pubs"]||Set.new).size,
    "terms_complete" => (d["ed_complete_terms"]||Set.new).size, "pubs_complete" => (d["ed_complete_pubs"]||Set.new).size }
end.sort_by { |x| x["tc"] }
File.write(File.join(options[:out_dir], "tc-stats.json"), JSON.generate(tc_list_data))

# HarmonizationPage: slim the harmonization data (designation collisions only)
harmonization_slim = {
  "designation_collisions" => collisions,
}
File.write(File.join(options[:out_dir], "harmonization-slim.json"), JSON.generate(harmonization_slim))

# ── Per-publication detail JSON (fetched on demand) ───────────────────────
pub_detail_dir = File.join(repo_root, "web", "public", "data", "publications")
FileUtils.mkdir_p(pub_detail_dir)
publications.each do |pub|
  pid = pub["id"]
  pub_terms = terms.select { |t| (t["publications"] || []).any? { |p| p["publication_id"] == pid } }
  pub_terms_slim = pub_terms.map { |t|
    instances = (t["publications"] || []).select { |p| p["publication_id"] == pid }
      .map { |p| p.is_a?(Hash) ? p.reject { |k, _| STRIP_FROM_PUB.include?(k) } : p }
    { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
      "identifier" => t["identifier"],
      "suggested_actions" => t["suggested_actions"],
      "publications" => instances }
  }
  pub_slug = pid.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
  File.write(File.join(pub_detail_dir, "#{pub_slug}.json"), JSON.generate({
    "publication" => pub, "terms" => pub_terms_slim
  }))
end

# ── Per-TC detail JSON (fetched on demand) ────────────────────────────────
tc_detail_dir = File.join(repo_root, "web", "public", "data", "tcs")
FileUtils.mkdir_p(tc_detail_dir)
tc_data.each do |tc, d|
  tc_terms = terms.select { |t| (t["publications"] || []).any? { |p| p["tc_sc"] == tc } }
  tc_terms_full = tc_terms.map { |t|
    slim_pubs = (t["publications"] || []).map { |p| p.is_a?(Hash) ? p.reject { |k, _| STRIP_FROM_PUB.include?(k) } : p }
    { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
      "identifier" => t["identifier"], "editions_present" => t["editions_present"],
      "suggested_actions" => t["suggested_actions"], "designations" => t["designations"],
      "publications" => slim_pubs }
  }
  tc_pubs_full = publications.select { |p| d["pubs"].include?(p["id"]) }
  tc_slug = tc.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
  File.write(File.join(tc_detail_dir, "#{tc_slug}.json"), JSON.generate({
    "tc" => tc, "terms" => tc_terms_full, "publications" => tc_pubs_full
  }))
end

puts "  Publications:        #{publications.size}"
puts "  Terms:               #{terms.size}"
puts "  TCs:                 #{tc_set.size}"
puts "  Editions:            #{edition_names.join(', ')}"
puts "  Harmonisation cands: #{candidates.size}"
puts "  Raw conflicts:       #{raw_conflicts.values.sum(&:size)}"
puts "  Designation coll:    #{collisions.values.sum(&:size)}"
puts "  Vocabulary gaps:     #{vocab_gaps.size}"
puts "  Output: #{options[:out_dir]}/"
