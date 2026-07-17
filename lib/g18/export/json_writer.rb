# frozen_string_literal: true

require "json"
require "fileutils"
require "set"

require_relative "renderer"
require_relative "deduplicator"
require_relative "../migration/conflicts"

module G18
  module Export
    # Writes all JSON output files consumed by the frontend. Each output
    # has a dedicated writer method so callers can target specific files
    # without re-running the full pipeline.
    class JsonWriter
      # Fields stripped from publication instances in lighter JSON files
      # (terms-medium, per-term detail, per-pub detail). Heavy provenance
      # fields only needed by analysis pipelines, not list views.
      STRIP_FROM_PUB = %w[
        source_lineage definition_paragraphs note_paragraphs example_paragraphs
        paragraph_sources note_sources example_sources annotations
        concept_sources localized_sources consistency consistency_reason
      ].freeze

      # Priority ranks for the dashboard worklist. Lower = higher priority.
      ACTION_PRIORITY = {
        "upgrade_vim" => 0, "upgrade_viml" => 0, "removed" => 0,
        "harmonize" => 1, "adopt_vim" => 1, "adopt_viml" => 1,
        "unique" => 2, "standardize" => 2,
      }.freeze

      def initialize(out_dir:, repo_root:)
        @out_dir = out_dir
        @repo_root = repo_root
        FileUtils.mkdir_p(@out_dir)
      end

      def call(terms:, publications:, vocab_gaps:, raw_conflicts:)
        write_publications(publications)
        write_terms(terms)
        write_terms_slim(terms)
        write_per_term_detail(terms)
        write_dashboard(terms, publications, vocab_gaps)
        write_tc_list(publications)
        write_edition_stats(terms)
        write_harmonization(terms)
        write_conflicts(terms)
        write_vocab_gaps(vocab_gaps)
        write_actions_data(terms)
        write_g18_dynamic(terms)
        write_readiness_stats(terms, raw_conflicts)
        write_leaderboard(terms)
        write_pub_list(terms, publications)
        write_tc_stats(terms)
        write_harmonization_slim
        write_per_publication_detail(terms, publications)
        write_per_tc_detail(terms, publications)
      end

      # ── Public accessors used by per-file writers below ────────────
      # Cache of computed stats so multiple writers can share them.
      def compute_collisions(terms)
        return @collisions if @collisions
        global_by_base = Hash.new { |h, k| h[k] = [] }
        global_by_name = Hash.new { |h, k| h[k] = [] }
        terms.each do |t|
          (t["publications"] || []).each do |p|
            ed = p["edition"] || "—"
            id = p["g18_entry"]
            next unless id
            designation = t["name"]
            source = p["publication_id"]
            base = G18::Migration::Conflicts.base_identifier(id)
            if base != id
              global_by_base[base] << { designation: designation, source: source, raw_id: id, edition: ed }
            end
            global_by_name[designation] << { id: id, source: source, edition: ed } if designation
          end
        end
        raw = build_raw_conflicts(global_by_base)
        cols = build_designation_collisions(global_by_name)
        @collisions = { raw: raw, designation: cols }
      end

      # All write_* methods are public so callers (Pipeline#call, ad-hoc
      # tooling, tests) can target specific outputs. Internal helpers
      # below are marked private individually.

      def write_publications(publications)
        File.write(File.join(@out_dir, "publications.json"), JSON.generate(publications))
      end

      def write_terms(terms)
        File.write(File.join(@out_dir, "terms.json"), JSON.generate(terms))
      end

      def write_terms_slim(terms)
        slim = terms.map do |t|
          pubs = t["publications"] || []
          deduped = Deduplicator.by_pub_and_clause(pubs)
          defs = Deduplicator.distinct_definitions(deduped)
          tc_counts = pubs.each_with_object(Hash.new(0)) do |p, h|
            next unless p["tc_sc"] && !p["tc_sc"].to_s.strip.empty?
            h[p["tc_sc"]] += 1
          end
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
            "distinct_def_count" => defs.size,
            "action_types" => (t["suggested_actions"] || []).map { |a| a["type"] },
            "designations" => t["designations"] || [],
            "official_concept_id" => t["official_concept"]&.dig("id"),
            "has_withdrawn" => pubs.any? { |p| p["withdrawn"] },
            "alignment_case" => t["alignment"]&.dig("case"),
            "alignment_status" => t["alignment"]&.dig("alignment"),
          }
        end
        File.write(File.join(@out_dir, "terms-slim.json"), JSON.generate(slim))
      end

      # terms-medium.json was removed — zero frontend consumers (verified
      # via grep across islands + tests). Per-term detail JSON in
      # web/public/data/terms/ provides the same shape on demand. Saves
      # 12MB per build.

      def write_per_term_detail(terms)
        dir = File.join(@repo_root, "web", "public", "data", "terms")
        FileUtils.mkdir_p(dir)
        terms.each do |t|
          slim_t = t.dup
          slim_t["publications"] = strip_pubs(t["publications"])
          File.write(File.join(dir, "#{t['slug']}.json"), JSON.generate(slim_t))
        end
      end

      def write_dashboard(terms, publications, vocab_gaps)
        kind_counts = terms.group_by { |t| t["kind"] }.transform_values(&:count)
        edition_counts = terms.each_with_object(Hash.new(0)) do |t, h|
          (t["editions_present"] || []).each { |e| h[e] += 1 }
        end

        gaps_viml_near_miss = vocab_gaps.count { |g| g["near_misses"]&.dig("viml") }
        gaps_vim_near_miss = vocab_gaps.count { |g| g["near_misses"]&.dig("vim") }
        gaps_no_match = vocab_gaps.count { |g| !g["near_misses"]&.dig("vim") && !g["near_misses"]&.dig("viml") }

        priority_terms = compute_priority_terms(terms)
        pub_lc = compute_pub_lifecycle(publications)
        concepts_from = compute_concepts_from(terms, publications)

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
          "concepts_from_current" => concepts_from[:current],
          "concepts_from_historic" => concepts_from[:historic],
          "alignment_counts" => terms.each_with_object(Hash.new(0)) { |t, h|
            status = t["alignment"]&.dig("alignment") || "none"
            h[status] += 1
          },
        }
        File.write(File.join(@out_dir, "dashboard.json"), JSON.generate(dashboard))
      end

      def compute_priority_terms(terms)
        terms
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
      end

      def compute_pub_lifecycle(publications)
        publications.each_with_object(Hash.new(0)) do |p, h|
          h[p["lifecycle"] || "current"] += 1
        end
      end

      def compute_concepts_from(terms, publications)
        current_ids = Set.new(publications.select { |p| p["lifecycle"] == "current" }.map { |p| p["id"] })
        historic_ids = Set.new(publications.select { |p| p["lifecycle"] == "retired" }.map { |p| p["id"] })
        from_current = 0
        from_historic = 0
        terms.each do |t|
          pub_ids = (t["publications"] || []).map { |p| p["publication_id"] }.compact
          has_current = pub_ids.any? { |pid| current_ids.include?(pid) }
          has_historic = pub_ids.any? { |pid| historic_ids.include?(pid) }
          from_current += 1 if has_current
          from_historic += 1 if has_historic && !has_current
        end
        { current: from_current, historic: from_historic }
      end

      def write_tc_list(publications)
        tc_set = Set.new
        publications.each do |p|
          tc_set << p["tc_sc"] if p["tc_sc"] && !p["tc_sc"].to_s.strip.empty?
        end
        File.write(File.join(@out_dir, "tc.json"), JSON.generate(tc_set.sort))
      end

      def write_edition_stats(terms)
        edition_names = terms.flat_map { |t| t["editions_present"] || [] }.uniq.sort
        primary_edition = (terms.find { |t| t["primary_edition"] } || {})["primary_edition"]
        stats = edition_names.map do |ed|
          instances = terms.sum { |t| (t["publications"] || []).count { |p| p["edition"] == ed } }
          terms_in_ed = terms.count { |t| (t["editions_present"] || []).include?(ed) }
          only_in_ed = terms.count { |t| t["editions_present"] == [ed] }
          har = terms.count do |t|
            pubs = (t["publications"] || []).select { |p| p["edition"] == ed }
            pubs.map { |p| p["publication_id"] }.compact.uniq.size > 1
          end
          {
            "edition" => ed,
            "primary" => ed == primary_edition,
            "instances" => instances,
            "terms" => terms_in_ed,
            "only_in_edition" => only_in_ed,
            "harmonization_candidates" => har,
          }
        end
        File.write(File.join(@out_dir, "edition-stats.json"),
                   JSON.generate("editions" => edition_names,
                                 "stats" => stats,
                                 "terms_in_both" => terms.count { |t| (t["editions_present"] || []).size > 1 }))
      end

      def write_harmonization(terms)
        candidates = terms.select do |t|
          (t["publications"] || []).map { |p| p["publication_id"] }.compact.uniq.size > 1
        end.sort_by { |t| -(t["publications"] || []).size }
        File.write(File.join(@out_dir, "harmonization.json"), JSON.generate(candidates))
      end

      def write_conflicts(terms)
        c = compute_collisions(terms)
        File.write(File.join(@out_dir, "conflicts.json"),
                   JSON.generate("raw" => c[:raw], "designation_collisions" => c[:designation]))
      end

      def build_raw_conflicts(global_by_base)
        raw = {}
        global_by_base.each do |base, entries|
          entries.group_by { |e| e[:edition] }.each do |ed, ed_entries|
            distinct = ed_entries.map { |e| e[:designation] }.uniq
            next if distinct.size < 2
            (raw[ed] ||= []) << {
              "id" => base,
              "concepts" => ed_entries.uniq { |e| e[:designation] }.map { |e|
                { "designation" => e[:designation], "source" => e[:source], "raw_id" => e[:raw_id] }
              },
            }
          end
        end
        raw.transform_values { |arr| arr.sort_by { |x| x["id"] } }
      end

      def build_designation_collisions(global_by_name)
        cols = {}
        global_by_name.each do |designation, entries|
          entries.group_by { |e| e[:edition] }.each do |ed, ed_entries|
            unique_ids = ed_entries.map { |e| e[:id] }.uniq
            next if unique_ids.size < 2
            (cols[ed] ||= []) << {
              "designation" => designation,
              "ids" => unique_ids.sort,
              "count" => ed_entries.size,
            }
          end
        end
        cols.transform_values { |arr| arr.sort_by { |x| [-x["ids"].size, x["designation"].downcase] } }
      end

      def write_vocab_gaps(vocab_gaps)
        sorted = vocab_gaps.sort_by do |t|
          has_match = t["near_misses"]["vim"] || t["near_misses"]["viml"]
          [has_match ? 1 : 0, -(t["publications"].size)]
        end
        File.write(File.join(@out_dir, "vocab-gaps.json"), JSON.generate(sorted))
      end

      def write_actions_data(terms)
        retire_action = { "type" => "retire", "priority" => "high",
          "description" => "Concept cited in a withdrawn OIML publication. Retire from G 18:current and G 18:202X.",
          "publication_ids" => [] }
        data = terms.map do |t|
          actions = (t["suggested_actions"] || []).dup
          withdrawn_pubs = (t["publications"] || []).select { |p| p["withdrawn"] }.map { |p| p["publication_id"] }.compact.uniq
          actions << { **retire_action, "publication_ids" => withdrawn_pubs } if withdrawn_pubs.any?
          next nil if actions.empty?
          { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
            "actions" => actions, "pub_count" => (t["publications"] || []).length,
            "editions_present" => t["editions_present"],
            "has_withdrawn" => withdrawn_pubs.any? }
        end.compact
        File.write(File.join(@out_dir, "actions-data.json"), JSON.generate(data))
      end

      def write_g18_dynamic(terms)
        data = terms.map { |t|
          pubs = t["publications"] || []
          { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
            "definition" => (pubs.first || {})["definition"] || "",
            "pub_count" => pubs.length } }
        File.write(File.join(@out_dir, "g18-dynamic.json"), JSON.generate(data))
      end

      def write_readiness_stats(terms, raw_conflicts)
        total = terms.length
        with_def = terms.count { |t| (t["publications"] || []).any? { |p| (p["definition"] || "").strip.size > 0 } }
        File.write(File.join(@out_dir, "readiness-stats.json"),
                   JSON.generate("total" => total, "with_definition" => with_def,
                                 "raw_conflicts" => raw_conflicts))
      end

      def write_leaderboard(terms)
        data = terms.map { |t|
          pubs = t["publications"] || []
          deduped = Deduplicator.by_pub_and_clause(pubs)
          defs = Deduplicator.distinct_definitions(deduped)
          { "slug" => t["slug"], "name" => t["name"],
            "pub_count" => deduped.length, "distinct_defs" => defs.size,
            "editions_present" => t["editions_present"] } }
        File.write(File.join(@out_dir, "leaderboard-data.json"), JSON.generate(data))
      end

      def write_pub_list(terms, publications)
        stats = {}
        terms.each do |t|
          (t["publications"] || []).each do |p|
            pid = p["publication_id"]
            next unless pid
            ed = p["edition"] || "?"
            stats[pid] ||= { "editions" => Hash.new(0), "term_count" => 0, "slugs" => [] }
            stats[pid]["editions"][ed] += 1
            stats[pid]["term_count"] += 1
            stats[pid]["slugs"] << t["slug"]
          end
        end
        list = publications.map do |p|
          s = stats[p["id"]] || { "editions" => {}, "term_count" => 0, "slugs" => [] }
          p.merge("term_count" => s["term_count"],
                  "edition_term_counts" => s["editions"])
        end
        File.write(File.join(@out_dir, "pub-list.json"), JSON.generate(list))
      end

      # Builds the tc_data index once and memoizes it. Shared between
      # write_tc_stats (summary counts) and write_per_tc_detail (full
      # detail per TC). Only pubs referenced by at least one term with
      # matching tc_sc are included — same scoping as the original script.
      def tc_data_for(terms)
        @tc_data ||= terms.each_with_object({}) do |t, acc|
          (t["publications"] || []).each do |p|
            tc = p["tc_sc"]
            next unless tc && !tc.to_s.strip.empty?
            ed = p["edition"] || "?"
            d = acc[tc] ||= { "terms" => Set.new, "pubs" => Set.new }
            d["terms"] << t["slug"]
            d["pubs"] << p["publication_id"] if p["publication_id"]
            d["ed_#{ed}_terms"] ||= Set.new
            d["ed_#{ed}_terms"] << t["slug"]
            d["ed_#{ed}_pubs"] ||= Set.new
            d["ed_#{ed}_pubs"] << p["publication_id"] if p["publication_id"]
          end
        end
      end

      def write_tc_stats(terms)
        list = tc_data_for(terms).map do |tc, d|
          { "tc" => tc, "terms_total" => d["terms"].size, "pubs_total" => d["pubs"].size,
            "terms_202X" => (d["ed_202X_terms"] || Set.new).size, "pubs_202X" => (d["ed_202X_pubs"] || Set.new).size,
            "terms_2010" => (d["ed_2010_terms"] || Set.new).size, "pubs_2010" => (d["ed_2010_pubs"] || Set.new).size,
            "terms_complete" => (d["ed_complete_terms"] || Set.new).size, "pubs_complete" => (d["ed_complete_pubs"] || Set.new).size }
        end.sort_by { |x| x["tc"] }
        File.write(File.join(@out_dir, "tc-stats.json"), JSON.generate(list))
      end

      def write_harmonization_slim
        # Requires compute_collisions to have been called already
        c = @collisions || { designation: {} }
        File.write(File.join(@out_dir, "harmonization-slim.json"),
                   JSON.generate("designation_collisions" => c[:designation]))
      end

      def write_per_publication_detail(terms, publications)
        dir = File.join(@repo_root, "web", "public", "data", "publications")
        FileUtils.mkdir_p(dir)
        publications.each do |pub|
          pid = pub["id"]
          pub_terms = terms.select { |t| (t["publications"] || []).any? { |p| p["publication_id"] == pid } }
          slim_terms = pub_terms.map { |t|
            instances = (t["publications"] || []).select { |p| p["publication_id"] == pid }
              .map { |p| strip_pub(p) }
            { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
              "identifier" => t["identifier"],
              "suggested_actions" => t["suggested_actions"],
              "publications" => instances }
          }
          slug = slugify(pid.to_s)
          File.write(File.join(dir, "#{slug}.json"), JSON.generate({
            "publication" => pub, "terms" => slim_terms
          }))
        end
      end

      def write_per_tc_detail(terms, publications)
        dir = File.join(@repo_root, "web", "public", "data", "tcs")
        FileUtils.mkdir_p(dir)
        tc_data_for(terms).each do |tc, d|
          tc_terms = terms.select { |t| (t["publications"] || []).any? { |p| p["tc_sc"] == tc } }
          slim_terms = tc_terms.map { |t|
            slim_pubs = strip_pubs(t["publications"])
            { "slug" => t["slug"], "name" => t["name"], "kind" => t["kind"],
              "identifier" => t["identifier"], "editions_present" => t["editions_present"],
              "suggested_actions" => t["suggested_actions"], "designations" => t["designations"],
              "publications" => slim_pubs }
          }
          tc_pubs_full = publications.select { |p| d["pubs"].include?(p["id"]) }
          slug = slugify(tc)
          File.write(File.join(dir, "#{slug}.json"), JSON.generate({
            "tc" => tc, "terms" => slim_terms, "publications" => tc_pubs_full
          }))
        end
      end

      def strip_pubs(pubs)
        (pubs || []).map { |p| strip_pub(p) }
      end

      def strip_pub(p)
        return p unless p.is_a?(Hash)
        p.reject { |k, _| STRIP_FROM_PUB.include?(k) }
      end

      def slugify(s)
        s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      end
    end
  end
end
