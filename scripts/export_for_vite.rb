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

def check_latest_edition(term_name, official_urn, latest_indices)
  return nil unless official_urn && term_name
  vocab = G18::Vocabulary.vocab(official_urn)
  return nil unless vocab
  info = LATEST_DATASETS[vocab]
  return nil unless info
  idx = latest_indices[vocab]
  return nil unless idx&.any?
  lookup = term_name.to_s.downcase.strip
  entry = idx[lookup]
  if entry
    {
      "found" => true,
      "vocab" => vocab.to_s,
      "latest_label" => info[:label],
      "latest_urn" => info[:urn],
      "concept_id" => entry[:id],
      "definition" => entry[:definition],
      "url" => "https://oimlsmart.github.io/vocab/#{info[:dir]}/concept/#{entry[:id]}",
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

# ── Publications ──────────────────────────────────────────────────────────
publications = File.exist?(options[:bib_path]) ?
  YAML.safe_load(File.read(options[:bib_path]), aliases: true) : []
File.write(File.join(options[:out_dir], "publications.json"),
           JSON.generate(publications))

# ── Terms ─────────────────────────────────────────────────────────────────
terms = []
Dir.glob(File.join(options[:data_dir], "*.yaml")).sort.each do |path|
  docs = YAML.safe_load_stream(File.read(path), aliases: true)
  next unless docs.first.is_a?(Hash)
  hash = docs.find { |d| d.is_a?(Hash) && d["data"] && d["data"]["term"] } || docs.first
  data = hash["data"] || {}
  oc_urn = data["official_concept"]&.dig("source")
  term = {
    "slug" => File.basename(path, ".yaml"),
    "identifier" => data["identifier"],
    "name" => data["term"],
    "designations" => data["designations"] || [],
    "kind" => data["kind"],
    "official_concept" => data["official_concept"],
    "editions_present" => data["editions_present"],
    "primary_edition" => data["primary_edition"],
    "latest_check" => oc_urn ? check_latest_edition(data["term"], oc_urn, latest_indices) : nil,
    "publications" => (data["publications"] || []).map do |p|
      p.merge(
        "defined" => data["kind"] == "defined_in_vim" || data["kind"] == "defined_in_viml",
        "official_concept" => data["official_concept"],
        "primary_edition" => data["primary_edition"],
      )
    end,
    "related" => hash["related"] || [],
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
    base = id.to_s.sub(/-[A-Z][0-9]+(-\d+)?\z/, "").sub(/[a-z]\z/, "")
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

puts "Exported for Vite:"
puts "  Publications:        #{publications.size}"
puts "  Terms:               #{terms.size}"
puts "  TCs:                 #{tc_set.size}"
puts "  Editions:            #{edition_names.join(', ')}"
puts "  Harmonisation cands: #{candidates.size}"
puts "  Raw conflicts:       #{raw_conflicts.values.sum(&:size)}"
puts "  Designation coll:    #{collisions.values.sum(&:size)}"
puts "  Output: #{options[:out_dir]}/"
