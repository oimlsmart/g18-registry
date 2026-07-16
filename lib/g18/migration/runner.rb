# frozen_string_literal: true

# Migration orchestrator: reads vocab datasets, groups by canonical term,
# writes per-term YAML, returns a Result.

module G18
  module Migration
    module Runner
      module_function

      def run(editions:, output_dir:, bib_path: nil, aliases_path: nil, vocab_dir: nil)
        editions = validate_inputs!(editions)
        raise ArgumentError, "no valid edition directories found" if editions.empty?
        primary    = editions.find { |e| e[:primary] } || editions.last
        # Load and merge ALL available bibliographies from edition paths.
        # Each vocab dataset has its own bibliography.yaml — merging gives
        # maximum coverage across editions.
        bib = {}
        if bib_path
          bib.merge!(Loaders.load_bibliography(bib_path))
        else
          editions.each do |e|
            path = File.join(e[:path], "bibliography.yaml")
          bib.merge!(Loaders.load_bibliography(path)) if File.exist?(path)
          end
        end
        aliases   = Normalize.load_term_aliases(aliases_path)
        vocab_dir ||= File.expand_path("..", editions.first[:path])

        entries_by_edition = {}
        all_entries        = []
        editions.each do |e|
          next unless Dir.exist?(File.join(e[:path], "concepts"))
          list = Loaders.load_concept_dir(File.join(e[:path], "concepts"), edition: e[:name])
          # Thread vocab type (:viml, :vim, or nil) through to each entry
          list.each { |entry| entry[:vocab] = e[:vocab] } if e[:vocab]
          entries_by_edition[e[:name]] = list
          all_entries.concat(list)
        end

        id_conflicts = Conflicts.detect_id_conflicts(entries_by_edition)

        tracking = { annotations_stripped: {}, alias_merges: {} }
        groups   = Builders.group_by_term(all_entries, aliases: aliases, tracking: tracking)
        FileUtils.rm_rf(output_dir)
        FileUtils.mkdir_p(output_dir)

        multi_edge              = []
        per_instance_edge_count = 0
        slug_collisions         = []
        files_written           = []
        assigned_slugs          = {}

        groups.keys.sort.each do |term_key|
          instances = groups[term_key]
          record    = Builders.build_term_record(term_key, instances, bib,
                                                 aliases:            aliases,
                                                 vocab_dir:          vocab_dir,
                                                 primary_edition:    primary[:name])
          slug = Loaders.slugify(term_key)
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
          multi_edge << term_key if Builders.merged_edges(instances).size > 1
          per_instance_edge_count += instances.sum { |e| Loaders.see_edges(e[:concept]).size }
        end

        total_pubs  = groups.values.sum { |instances| instances.size }
        total_edges = groups.values.sum { |instances| Builders.merged_edges(instances).size }

        Result.new(
          files_written:           files_written,
          instance_count:          total_pubs,
          unique_term_count:       groups.size,
          related_edge_count:      total_edges,
          per_instance_edge_count: per_instance_edge_count,
          multi_edge_terms:        multi_edge.sort,
          slug_collisions:         slug_collisions.sort_by { |c| c[:slug] },
          annotations_stripped:    tracking[:annotations_stripped],
          alias_merges:            tracking[:alias_merges],
          id_conflicts:            id_conflicts,
          editions:                editions.map { |e| { name: e[:name], primary: e[:name] == primary[:name], concept_count: entries_by_edition[e[:name]]&.size || 0 } },
        )
      end

      def serialize_record(record)
        yaml = YAML.dump(record)
        yaml.start_with?("---\n") ? yaml : "---\n" + yaml
      end

      def validate_inputs!(editions)
        raise ArgumentError, "editions must be a non-empty Array" unless editions.is_a?(Array) && editions.any?
        editions.each do |e|
          raise ArgumentError, "edition missing :name or :path" unless e.is_a?(Hash) && e[:name] && e[:path]
        end
        # Skip editions whose directories don't exist (e.g. g18-current
        # not yet pushed to the vocab repo). Warn so it's visible.
        missing = editions.reject { |e| Dir.exist?(e[:path]) }
        missing.each { |e| warn "  WARN: edition dir not found, skipping: #{e[:name]} (#{e[:path]})" }
        editions - missing
      end
    end
  end
end
