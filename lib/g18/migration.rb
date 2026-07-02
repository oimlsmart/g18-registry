# frozen_string_literal: true

require "yaml"
require "digest"
require "fileutils"
require "set"
require_relative "vocabulary"
require_relative "model/identifier"

module G18
  # Migrates oimlsmart/vocab datasets/g18/ (per-instance) into the per-term
  # model used by this registry.
  #
  # Source files are multi-document YAML: the first document is concept
  # metadata (identifier, sources, related), the second is the localized
  # concept (definition, terms). One source file = one (term, publication)
  # instance. The migration groups these by lowercased preferred designation
  # and emits one file per unique term.
  module Migration
    SOURCE_INSTANCE_COUNT = 2125
    EXPECTED_RELATED_EDGES = 101

    URN_TO_DATASET = {
      "urn:oiml:pub:v:1:1968" => "viml-1968",
      "urn:oiml:pub:v:1:2000" => "viml-2000",
      "urn:oiml:pub:v:1:2013" => "viml-2013",
      "urn:oiml:pub:v:1:2022" => "viml-2022",
      "urn:oiml:pub:v:2:1993" => "vim-1993",
      "urn:oiml:pub:v:2:2007" => "vim-2007",
      "urn:oiml:pub:v:2:2010" => "vim-2010",
      "urn:oiml:pub:v:2:2012" => "vim-2012",
    }.freeze

    VOCAB_BASE_URL = "https://oimlsmart.github.io/vocab"

    Result = Struct.new(:files_written, :instance_count, :unique_term_count, :related_edge_count, :per_instance_edge_count, :multi_edge_terms, :slug_collisions, :annotations_stripped, :alias_merges, :id_conflicts, :editions, keyword_init: true)

    module_function

    # Strip trailing editorial annotations from a designation.
    #
    # G 18 source designations sometimes include bracketed editorial notes
    # that are not part of the term itself:
    #   "reference conditions [VIM:1993, 5.7 [1]]"
    #   "weigh length (L) [not applicable to belt weighers inclusive of conveyor]"
    #   "weighing cycle [applicable only to belt weighers whose ...] it"
    #
    # The match is anchored to specific editorial prefixes (VIM citations,
    # applicability notes, footnote markers) so it does NOT swallow
    # `stem:[...]` math markup that legitimately ends a designation.
    EDITORIAL_ANNOTATION_RE = /
      \s*
      \[
        (?:
          VIM | VIML
          | Adapted\s+from
          | (?:not\s+)?applicable
          | OIML
          | \d+
        )
        [^\]]*
      \]
      .*
      \z
    /ix.freeze

    def normalize_designation(raw)
      raw.to_s
        .sub(EDITORIAL_ANNOTATION_RE, "")
        .gsub(/ /, " ")       # non-breaking space → regular space
        .gsub(/‑/, "-")       # non-breaking hyphen → regular hyphen
        .strip
    end

    def load_term_aliases(path)
      return {} unless path && File.exist?(path)
      yaml = YAML.safe_load(File.read(path), aliases: true) || {}
      yaml.each_with_object({}) do |(canonical, variants), h|
        next unless canonical.is_a?(String) && !canonical.empty?
        h[canonical.downcase] = canonical
        Array(variants).each do |v|
          next unless v.is_a?(String) && !v.empty?
          h[v.downcase] = canonical
        end
      end
    end

    def slugify(term)
      G18::Model::Identifier.slugify(term)
    end

    def deterministic_uuid(name)
      G18::Model::Identifier.deterministic_uuid(name)
    end

    def parse_year(s)
      m = s.to_s.match(/:(\d{4})\z/)
      m && m[1].to_i
    end

    def vocab_concept_url(urn, id)
      dataset = URN_TO_DATASET[urn]
      return nil unless dataset && id
      "#{VOCAB_BASE_URL}/#{dataset}/concept/#{id}"
    end

    def kind_for_urn(urn)
      case urn
      when /\Aurn:oiml:pub:v:1:/ then "defined_in_viml"
      when /\Aurn:oiml:pub:v:2:/ then "defined_in_vim"
      else "undefined"
      end
    end

    def load_bibliography(path)
      entries = YAML.safe_load(File.read(path), aliases: true) || []
      entries = entries.is_a?(Array) ? entries : [entries]
      entries.each_with_object({}) { |e, h| h[e["id"]] = e if e.is_a?(Hash) }
    end

    def load_concept_dir(dir, edition: nil)
      Dir.glob(File.join(dir, "*.yaml")).sort.map do |file|
        load_concept_file(file, edition: edition)
      end
    end

    def load_concept_file(file, edition: nil)
      docs = YAML.safe_load_stream(File.read(file), filename: file, aliases: true)
      meta = docs.find { |d| d && d.is_a?(Hash) && d["data"] && d["data"]["identifier"] }
      loc = docs.find { |d| d && d.is_a?(Hash) && d["data"] && d["data"]["definition"] }
      { file: file, meta: meta, loc: loc, edition: edition }
    end

    def preferred_designation(loc)
      return nil unless loc
      terms = loc.dig("data", "terms")
      return nil unless terms && !terms.empty?
      pref = terms.find { |t| t["normative_status"] == "preferred" } || terms.first
      pref["designation"]
    end

    def definition_text(loc)
      return "" unless loc
      defs = loc.dig("data", "definition")
      return "" unless defs
      defs.map { |d| d["content"] if d.is_a?(Hash) }.compact.join("\n")
    end

    def notes_text(loc)
      return [] unless loc
      notes = loc.dig("data", "notes")
      return [] unless notes
      notes.map { |n| n["content"] if n.is_a?(Hash) }.compact
    end

    def see_edges(meta)
      return [] unless meta
      related = meta["related"]
      return [] unless related.is_a?(Array)
      related.select { |r| r.is_a?(Hash) && r["type"] == "see" }
    end

    def source_ref(meta)
      meta.dig("data", "sources", 0, "origin", "ref", "source")
    end

    def clause_ref(meta)
      meta.dig("data", "sources", 0, "locality", "reference_from")
    end

    # Group instances by canonical term key. Returns a hash
    # `{ canonical_downcased => [entries...] }` plus tracking info via the
    # `tracking` hash (mutated in place):
    #   tracking[:annotations_stripped] = { original => cleaned }
    #   tracking[:alias_merges] = { canonical => [variant, ...] }
    def group_by_term(entries, aliases:, tracking:)
      groups = Hash.new { |h, k| h[k] = [] }
      variants_seen = Hash.new { |h, k| h[k] = Set.new }
      entries.each do |e|
        raw = preferred_designation(e[:loc])
        next unless raw && !raw.empty?
        cleaned = normalize_designation(raw)
        tracking[:annotations_stripped][raw] = cleaned if cleaned != raw
        canonical = aliases[cleaned.downcase] || cleaned
        if canonical.downcase != cleaned.downcase
          variants_seen[canonical.downcase] << cleaned
        end
        groups[canonical.downcase] << e
      end
      tracking[:alias_merges] = variants_seen.each_with_object({}) do |(canonical_key, variants), h|
        h[aliases[canonical_key] || canonical_key] = variants.to_a.sort
      end
      groups
    end

    def build_publication_entry(entry, bib)
      meta = entry[:meta]
      loc = entry[:loc]
      src_id = source_ref(meta)
      bib_e = bib[src_id]
      edges = see_edges(meta)
      pub = {
        "edition"        => entry[:edition],
        "publication"    => (bib_e && bib_e["reference"]) || src_id,
        "publication_id" => src_id,
        "tc_sc"          => (bib_e && bib_e["tc_sc"]) || "",
        "year"           => (bib_e && parse_year(bib_e["id"])) || parse_year(src_id),
        "clause"         => clause_ref(meta),
        "link"           => (bib_e && bib_e["link"]),
        "g18_entry"      => meta.dig("data", "identifier"),
        "definition"     => definition_text(loc),
        "notes"          => notes_text(loc),
        "consistency"    => "pending",
        "consistency_reason" => "",
      }
      # Preserve each instance's own see-edges on the publication entry, so the
      # total count of `publications[*].related` across the dataset equals the
      # number of source instances that asserted an edge (101). The term-level
      # `related` block below is the deduplicated canonical superset.
      pub["related"] = edges.map { |e| { "type" => "see", "ref" => e["ref"] } } unless edges.empty?
      pub
    end

    # Detect identifiers in the source publication that are reused for two
    # distinct concepts (a numbering error in the source). Returns a hash
    # `{ edition_name => { id => [{ designation:, source: }, ...] } }` for
    # every ID that has more than one distinct designation in that edition.
    def detect_id_conflicts(entries_by_edition)
      conflicts = {}
      entries_by_edition.each do |edition, entries|
        # Map: identifier -> set of (designation, source) tuples.
        by_id = Hash.new { |h, k| h[k] = [] }
        entries.each do |e|
          id = e[:meta]&.dig("data", "identifier")
          next unless id
          designation = preferred_designation(e[:loc])
          next unless designation
          source = source_ref(e[:meta])
          by_id[id] << { designation: designation, source: source } unless by_id[id].any? { |x| x[:designation] == designation && x[:source] == source }
        end
        ed_conflicts = by_id.select { |_, arr| arr.size > 1 }
        next if ed_conflicts.empty?
        conflicts[edition] = ed_conflicts.sort.transform_values { |v| v.sort_by { |x| x[:designation].downcase } }
      end
      conflicts
    end

    # Build the merged see-edges for a term (deduped, lowest-identifier first).
    def merged_edges(instances)
      instances
        .sort_by { |e| e[:meta].dig("data", "identifier").to_s }
        .flat_map { |e| see_edges(e[:meta]) }
        .uniq { |edge| [edge.dig("ref", "source"), edge.dig("ref", "id")] }
    end

# Loads the official definition text for a VIM/VIML concept from the
    # sibling vocab checkout. `vocab_dir` should be the dataset root
    # (i.e. `vocab/datasets/`); VIM/VIML concepts live in sibling dirs
    # at `<vocab_dir>/<dataset>/concepts/<id>.yaml`. Returns nil if the
    # vocab file isn't found or has no English definition.
    def load_official_definition_text(vocab_dir, urn, concept_id)
      dataset = URN_TO_DATASET[urn]
      return nil unless dataset && concept_id && vocab_dir
      path = File.join(vocab_dir, dataset, "concepts", "#{concept_id}.yaml")
      return nil unless File.exist?(path)
      docs = YAML.safe_load_stream(File.read(path), filename: path, aliases: true)
      loc = docs.find { |d| d && d.is_a?(Hash) && d.dig("data", "definition") }
      return nil unless loc
      defs = loc.dig("data", "definition") || []
      text = defs.map { |d| d["content"] if d.is_a?(Hash) }.compact.join("\n").strip
      text.empty? ? nil : text
    end

    # Enrich a VIM/VIML reference (URN + concept id) with edition metadata
    # so the term YAML carries everything the template needs without a
    # runtime fetch. Returns a hash with: urn, id, url, definition_text,
    # edition_label, role, year, vocab — or the input hash unchanged if
    # the URN is not a recognised VIM/VIML edition.
    def enrich_authority_ref(vocab_dir, ref)
      return ref unless ref.is_a?(Hash)
      urn = ref["source"]
      return ref unless G18::Vocabulary.vocab(urn)
      concept_id = ref["id"]
      enriched = ref.dup
      enriched["definition_text"] ||= load_official_definition_text(vocab_dir, urn, concept_id)
      enriched["edition_label"] = G18::Vocabulary.label(urn)
      enriched["vocab"] = G18::Vocabulary.vocab(urn).to_s
      enriched["role"] = G18::Vocabulary.role(urn).to_s
      enriched["year"] = G18::Vocabulary.year(urn)
      enriched
    end

    def build_term_record(term_key, instances, bib, aliases:, vocab_dir: nil, primary_edition: nil)
      # Sort: primary edition first, then by edition name, then by identifier.
      sorted = instances.sort_by do |e|
        edition_rank = e[:edition] == primary_edition ? 0 : 1
        [edition_rank, e[:edition].to_s, e[:meta].dig("data", "identifier").to_s]
      end
      first = sorted.first
      edges = merged_edges(sorted)
      kind, official = pick_official(edges)
      pubs = sorted
        .map { |e| build_publication_entry(e, bib) }
        .sort_by { |p| [p["edition"].to_s, -(p["year"] || 0), p["publication_id"].to_s, p["clause"].to_s] }

      # Display name: prefer the alias canonical (preserves exact casing
      # from the aliases file); otherwise use the first instance's cleaned
      # designation.
      display_name = aliases[term_key] || normalize_designation(preferred_designation(first[:loc]) || term_key)

      # Enrich the official concept with VIM/VIML edition metadata + the
      # authoritative definition text so the term page renders the baseline
      # directly without a runtime fetch from the vocab repo.
      if official && vocab_dir
        official = enrich_authority_ref(vocab_dir, official)
      end

      # Enrich every per-term `related` edge the same way.
      enriched_edges = edges.map do |edge|
        next edge unless vocab_dir && edge.is_a?(Hash)
        ref = edge["ref"]
        next edge unless ref
        edge.merge("ref" => enrich_authority_ref(vocab_dir, ref))
      end

      editions_present = instances.map { |e| e[:edition] }.compact.uniq.sort

      {
        "data" => {
          "identifier"       => first[:meta].dig("data", "identifier"),
          "term"             => display_name,
          "kind"             => kind,
          "official_concept" => official,
          "editions_present" => editions_present,
          "primary_edition"  => primary_edition,
          "publications"     => pubs,
        },
        "status"         => "current",
        "id"             => deterministic_uuid(term_key),
        "schema_version" => "3",
        "related"        => enriched_edges.map { |e| { "type" => e["type"], "ref" => e["ref"] } },
      }
    end

    def pick_official(edges)
      return ["undefined", nil] if edges.empty?
      edge = edges.first
      ref = edge["ref"] || {}
      urn = ref["source"]
      id = ref["id"]
      [kind_for_urn(urn), { "source" => urn, "id" => id, "url" => vocab_concept_url(urn, id) }]
    end

    def run(editions:, output_dir:, bib_path: nil, aliases_path: nil, vocab_dir: nil)
      raise ArgumentError, "editions must be a non-empty Array" unless editions.is_a?(Array) && editions.any?
      editions.each do |e|
        raise ArgumentError, "edition missing :name or :path" unless e.is_a?(Hash) && e[:name] && e[:path]
        raise ArgumentError, "edition dir not found: #{e[:path]}" unless Dir.exist?(e[:path])
      end
      primary = editions.find { |e| e[:primary] } || editions.last
      # Bibliography: explicit path, else first edition that has one.
      bib_path ||= editions.map { |e| File.join(e[:path], "bibliography.yaml") }.find { |p| File.exist?(p) }
      bib = bib_path ? load_bibliography(bib_path) : {}
      aliases = load_term_aliases(aliases_path)
      # vocab_dir (parent of all edition dirs) for VIM/VIML lookups.
      # Walk up from any edition path; all editions share the same parent
      # (`vocab/datasets/`) so any one works.
      vocab_dir ||= File.expand_path("..", editions.first[:path])

      entries_by_edition = {}
      all_entries = []
      editions.each do |e|
        next unless Dir.exist?(File.join(e[:path], "concepts"))
        list = load_concept_dir(File.join(e[:path], "concepts"), edition: e[:name])
        entries_by_edition[e[:name]] = list
        all_entries.concat(list)
      end

      id_conflicts = detect_id_conflicts(entries_by_edition)

      tracking = { annotations_stripped: {}, alias_merges: {} }
      groups = group_by_term(all_entries, aliases: aliases, tracking: tracking)
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)

      multi_edge = []
      per_instance_edge_count = 0
      slug_collisions = []
      files_written = []
      assigned_slugs = {}

      groups.keys.sort.each do |term_key|
        instances = groups[term_key]
        record = build_term_record(term_key, instances, bib, aliases: aliases, vocab_dir: vocab_dir, primary_edition: primary[:name])
        slug = slugify(term_key)
        if assigned_slugs.key?(slug)
          existing_owner = assigned_slugs[slug]
          if slug_collisions.empty? || slug_collisions.none? { |c| c[:slug] == slug }
            slug_collisions << { slug: slug, terms: [existing_owner] }
          end
          slug_collisions.find { |c| c[:slug] == slug }[:terms] << term_key
          lowest_id = record.dig("data", "identifier").to_s
          slug = "#{slug}-#{lowest_id}"
        end
        assigned_slugs[slug] = term_key
        path = File.join(output_dir, "#{slug}.yaml")
        File.write(path, serialize_record(record))
        files_written << path
        multi_edge << term_key if merged_edges(instances).size > 1
        per_instance_edge_count += instances.sum { |e| see_edges(e[:meta]).size }
      end

      total_pubs = groups.values.sum { |instances| instances.size }
      total_edges = groups.values.sum { |instances| merged_edges(instances).size }

      Result.new(
        files_written: files_written,
        instance_count: total_pubs,
        unique_term_count: groups.size,
        related_edge_count: total_edges,
        per_instance_edge_count: per_instance_edge_count,
        multi_edge_terms: multi_edge.sort,
        slug_collisions: slug_collisions.sort_by { |c| c[:slug] },
        annotations_stripped: tracking[:annotations_stripped],
        alias_merges: tracking[:alias_merges],
        id_conflicts: id_conflicts,
        editions: editions.map { |e| { name: e[:name], primary: e[:name] == primary[:name], concept_count: entries_by_edition[e[:name]]&.size || 0 } },
      )
    end

    def serialize_record(record)
      yaml = YAML.dump(record)
      yaml.start_with?("---\n") ? yaml : "---\n" + yaml
    end
  end
end
