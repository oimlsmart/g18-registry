#!/usr/bin/env ruby
# frozen_string_literal: true

# Export per-term YAML data and bibliography into JSON for the Vite + Vue
# frontend. Reads from `data/` and `tc-sc/publications.yaml`, writes
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
require_relative "../lib/g18/vocabulary"
require_relative "../lib/g18/actions"
require_relative "../lib/g18/fuzzy_match"
require_relative "../lib/g18/migration/conflicts"

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
  bib_path: File.join(repo_root, "tc-sc", "publications.yaml"),
  out_dir: File.join(repo_root, "web", "src", "data"),
  vocab_root: ENV.fetch("VOCAB_ROOT", default_vocab_root),
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.on("--data-dir DIR", String) { |v| options[:data_dir] = v }
  opts.on("--bib-path PATH", String) { |v| options[:bib_path] = v }
  opts.on("--out-dir DIR", String) { |v| options[:out_dir] = v }
  opts.on("--vocab-root DIR", String) { |v| options[:vocab_root] = v }
end.parse!

FileUtils.mkdir_p(options[:out_dir])

# ── Build latest-edition designation index ────────────────────────────────
# For each vocabulary (VIM/VIML), load the LATEST edition's concepts and
# build a { designation_downcase => { id:, definition: } } index. Used to
# definitively check whether a term still exists in the latest edition.

LATEST_DATASETS = {
  vim:  { urn: G18::Vocabulary::LATEST_VIM_URN,  dir: "vim-2012",  label: "VIM 2012" },
  viml: { urn: G18::Vocabulary::LATEST_VIML_URN, dir: "viml-2022", label: "VIML 2022" },
}.freeze

def load_latest_designation_index(vocab_root, dataset_dir)
  idx = {}
  concepts_dir = File.join(vocab_root, dataset_dir, "concepts")
  return idx unless Dir.exist?(concepts_dir)
  Dir.glob(File.join(concepts_dir, "*.yaml")).each do |path|
    docs = begin
      YAML.safe_load_stream(File.read(path), aliases: true)
    rescue Psych::SyntaxError
      next
    end
    loc = docs.find { |d| d && d.is_a?(Hash) && d.dig("data", "definition") }
    next unless loc
    terms = loc.dig("data", "terms") || []
    pref = terms.find { |t| t["normative_status"] == "preferred" } || terms.first
    next unless pref && pref["designation"]
    designation = pref["designation"].to_s.downcase.strip
    defs = loc.dig("data", "definition") || []
    defn_text = defs.map { |d| d["content"] if d.is_a?(Hash) }.compact.join("\n").strip
    meta = docs.find { |d| d && d.is_a?(Hash) && d.dig("data", "identifier") }
    id = meta&.dig("data", "identifier")
    idx[designation] = { id: id, definition: defn_text } if id && !defn_text.empty?
  end
  idx
end

# Load the full concept details (designations, definitions, notes,
# examples) for a given concept ID from the vocab repo. Returns a
# hash with eng/fra localizations so the term detail page can show
# the complete VIM/VIML concept as TC 1's harmonisation target.
def load_concept_details(vocab_root, dataset_dir, concept_id)
  path = File.join(vocab_root, dataset_dir, "concepts", "#{concept_id}.yaml")
  return nil unless File.exist?(path)
  docs = begin
    YAML.safe_load_stream(File.read(path), aliases: true)
  rescue Psych::SyntaxError
    return nil
  end
  # First doc is the managed concept (metadata); remaining docs are
  # localized concepts keyed by language_code.
  loc_docs = docs.select { |d| d.is_a?(Hash) && d.dig("data", "language_code") }
  out = {}
  loc_docs.each do |doc|
    data = doc["data"] || {}
    lang = data["language_code"]
    next unless lang
    out[lang] = {
      "designations" => (data["terms"] || []).map do |t|
        {
          "type" => t["type"],
          "status" => t["normative_status"] || "preferred",
          "text" => t["designation"],
        }
      end,
      "definitions" => Array(data["definition"]).map { |d| d.is_a?(Hash) ? d["content"] : nil }.compact,
      "notes" => Array(data["notes"]).map { |n| n.is_a?(Hash) ? n["content"] : nil }.compact,
      "examples" => Array(data["examples"]).map { |e| e.is_a?(Hash) ? e["content"] : nil }.compact,
    }
  end
  out.empty? ? nil : out
end
latest_indices = {}
LATEST_DATASETS.each do |vocab, info|
  path = File.join(options[:vocab_root], info[:dir], "concepts")
  if Dir.exist?(path)
    latest_indices[vocab] = load_latest_designation_index(options[:vocab_root], info[:dir])
    warn "  Latest #{info[:label]}: #{latest_indices[vocab].size} designations indexed"
  else
    warn "  Latest #{info[:label]}: concepts dir not found at #{path} — latest_check will be skipped"
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
def check_vocab_presence(term_name, latest_indices)
  result = { "vim" => nil, "viml" => nil }
  return result unless term_name
  %w[vim viml].each do |vocab|
    idx = latest_indices[vocab.to_sym] || latest_indices[vocab]
    next unless idx&.any?
    lookup = term_name.to_s.downcase.strip
    if idx.key?(lookup)
      info = LATEST_DATASETS[vocab.to_sym]
      entry = idx[lookup]
      result[vocab] = {
        found: true,
        match_type: "exact",
        designation: term_name,
        concept_id: entry[:id],
        definition: entry[:definition],
        latest_label: info[:label],
        url: "https://www.oimlsmart.org/vocab/dataset/#{info[:dir]}/concept/#{entry[:id]}",
      }
    else
      m = G18::FuzzyMatch.match(term_name, idx)
      next unless m
      info = LATEST_DATASETS[vocab]
      result[vocab] = {
        found: false,
        match_type: "fuzzy",
        designation: m[:designation],
        concept_id: m[:entry][:id],
        definition: m[:entry][:definition],
        similarity: m[:similarity].round(3),
        latest_label: info[:label],
        url: "https://www.oimlsmart.org/vocab/dataset/#{info[:dir]}/concept/#{m[:entry][:id]}",
      }
    end
  end
  result
end

# ── Publications ──────────────────────────────────────────────────────────
publications = File.exist?(options[:bib_path]) ?
  YAML.safe_load(File.read(options[:bib_path]), aliases: true) : []
File.write(File.join(options[:out_dir], "publications.json"),
           JSON.generate(publications))

# ── Terms ─────────────────────────────────────────────────────────────────
terms = []
vocab_gaps = []
Dir.glob(File.join(options[:data_dir], "*.yaml")).sort.each do |path|
  docs = YAML.safe_load_stream(File.read(path), aliases: true)
  next unless docs.first.is_a?(Hash)
  hash = docs.find { |d| d.is_a?(Hash) && d["data"] && d["data"]["term"] } || docs.first
  data = hash["data"] || {}
  oc_urn = data["official_concept"]&.dig("source")
  # Compute vocab_presence (exact + fuzzy match) for OIML-original terms
  # so the compiler can enrich action descriptions with near-miss guidance.
  # Backward compat: accept legacy "undefined" value too.
  is_oiml_original = data["kind"] == "oiml_original" || data["kind"] == "undefined"
  vocab_presence = is_oiml_original ?
    check_vocab_presence(data["term"], latest_indices) : nil
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
    # Cited edition: derive directory from the URN year.
    if oc_urn
      cited_dir = oc_urn.match(/v:[12]:(\d{4})/) do |m|
        year = m[1]
        vocab_prefix = oc_urn.include?("v:2") ? "vim" : "viml"
        "#{vocab_prefix}-#{year}"
      end
      if cited_dir
        cited_concept = load_concept_details(options[:vocab_root], cited_dir, oc_id)
      end
    end
    # Latest edition: load using latest_check concept_id (may differ
    # from cited id due to renumbering between editions).
    if v && (info = LATEST_DATASETS[v])
      latest_id = latest && latest["found"] ? latest["concept_id"] : oc_id
      latest_concept = load_concept_details(options[:vocab_root], info[:dir], latest_id)
    end
  end
  full_concept = latest_concept || cited_concept
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
    ),
    "editions_present" => data["editions_present"],
    "primary_edition" => data["primary_edition"],
    "latest_check" => latest,
    "suggested_actions" => G18::Actions::Compiler.for_term(
      "data" => data, "latest_check" => latest,
      "vocab_presence" => vocab_presence,
      "canonical_mismatch" => canonical_mismatch
    ).map(&:to_h),
    "publications" => (data["publications"] || []).map do |p|
      render_stem_deep(p).merge(
        "defined" => data["kind"] == "defined_in_vim" || data["kind"] == "defined_in_viml",
        "official_concept" => render_stem_deep(data["official_concept"]),
        "primary_edition" => data["primary_edition"],
      )
    end,
    "related" => render_stem_deep(hash["related"] || []),
  }
  terms << term
end
File.write(File.join(options[:out_dir], "terms.json"),
           JSON.generate(terms))

# ── Per-term page data (slug → full hash) ─────────────────────────────────
by_slug = terms.each_with_object({}) { |t, h| h[t["slug"]] = t }
File.write(File.join(options[:out_dir], "term-by-slug.json"),
           JSON.generate(by_slug))

# ── TC/SC list ────────────────────────────────────────────────────────────
tc_set = Set.new
publications.each do |p|
  tc_set << p["tc_sc"] if p["tc_sc"] && !p["tc_sc"].to_s.strip.empty?
end
tc_set << "(Unattributed)"
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
puts "  Publications:        #{publications.size}"
puts "  Terms:               #{terms.size}"
puts "  TCs:                 #{tc_set.size}"
puts "  Editions:            #{edition_names.join(', ')}"
puts "  Harmonisation cands: #{candidates.size}"
puts "  Raw conflicts:       #{raw_conflicts.values.sum(&:size)}"
puts "  Designation coll:    #{collisions.values.sum(&:size)}"
puts "  Vocabulary gaps:     #{vocab_gaps.size}"
puts "  Output: #{options[:out_dir]}/"
