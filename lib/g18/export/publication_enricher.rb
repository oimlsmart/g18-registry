# frozen_string_literal: true

require "yaml"
require "set"

module G18
  module Export
    # Loads OIML publications from vocab-repo bibliographies and enriches
    # each one with TC/SC, withdrawn status, and lifecycle (current /
    # retired / withdrawn) computed from the relaton-data-oiml index.
    #
    # Returns an EnrichmentResult holding publications + lookup maps.
    class PublicationEnricher
      # Structured result. Carry the maps alongside publications so the
      # term processor and JSON writer can look up TC/SC and lifecycle
      # by publication id without re-parsing relaton.
      Result = Struct.new(:publications, :tc_sc_map, :withdrawn_set, :lifecycle_map, keyword_init: true)

      BIB_FILES = %w[oiml-complete g18-202X g18-2010].freeze
      RELATON_INDEX = "index-v2.yaml"

      # Maps relaton pubid types to OIML letter prefixes.
      PUBID_TYPE_PREFIX = {
        "pubid:oiml:basic-publication" => "B",
        "pubid:oiml:recommendation" => "R",
        "pubid:oiml:document" => "D",
        "pubid:oiml:international-document" => "D",
      }.freeze

      def initialize(vocab_root:, relaton_root:)
        @vocab_root = vocab_root
        @relaton_root = relaton_root
      end

      def call
        publications = load_publications
        enrich_from_relaton(publications)
        assign_lifecycle(publications)
        Result.new(
          publications: publications,
          tc_sc_map: build_tc_sc_map(publications),
          withdrawn_set: publications.select { |p| p["withdrawn"] }.map { |p| p["id"] }.to_set,
          lifecycle_map: publications.each_with_object({}) { |p, h| h[p["id"]] = p["lifecycle"] if p["lifecycle"] },
        )
      end

      private

      def load_publications
        publications = []
        bib_paths.each do |path|
          docs = YAML.safe_load(File.read(path), aliases: true) || []
          docs.each do |p|
            publications << p unless publications.any? { |e| e["id"] == p["id"] }
          end
        end
        publications
      end

      def bib_paths
        BIB_FILES.map { |d| File.join(@vocab_root, d, "bibliography.yaml") }
                 .select { |f| File.exist?(f) }
      end

      def enrich_from_relaton(publications)
        index_path = File.join(@relaton_root, RELATON_INDEX)
        return unless File.exist?(index_path)
        index = YAML.load_file(index_path, aliases: true) || []
        relaton_file_map = build_relaton_file_map(index)
        publications.each do |p|
          relaton_file = relaton_file_map[p["id"]]
          next unless relaton_file && File.exist?(relaton_file)
          apply_relaton_doc(p, relaton_file)
        end
      end

      def build_relaton_file_map(index)
        map = {}
        index.each do |entry|
          raw_id = entry[:id] || entry["id"]
          file = entry[:file] || entry["file"]
          next if raw_id.nil? || file.nil?
          id_str = convert_pubid(raw_id)
          next if id_str.nil?
          next if id_str =~ /\s\([EF]\)\s*$/
          map[id_str] = File.join(@relaton_root, file.to_s)
        end
        map
      end

      def convert_pubid(id)
        if id.is_a?(String)
          id
        elsif id["_type"] == "pubid:oiml:amendment"
          base = convert_pubid(id["base_identifier"])
          "#{base}+Amendment:#{id['year']}"
        else
          letter = PUBID_TYPE_PREFIX[id["_type"]]
          return nil unless letter
          s = "#{id['publisher']} #{letter} #{id['number']}"
          s += "-#{id['part']}" if id["part"]
          s += ":#{id['year']}" if id["year"]
          s += " (#{id['language']})" if id["language"]
          s
        end
      end

      def apply_relaton_doc(p, relaton_file)
        doc = YAML.load_file(relaton_file, aliases: true) rescue return
        tc_part, sc_part = nil
        (doc["contributor"] || []).each do |c|
          (c.dig("organization", "subdivision") || []).each do |sub|
            content = (sub["identifier"] || []).map { |i| i["content"] }.compact.first
            next unless content
            case sub["type"]
            when "technical-committee" then tc_part ||= content
            when "subcommittee" then sc_part ||= content
            end
          end
        end
        parts = [tc_part, sc_part].compact
        p["tc_sc"] = parts.join("/") if parts.any?
        stage = doc.dig("status", "stage")
        stage_str = stage.is_a?(Hash) ? stage["content"] : stage
        p["withdrawn"] = true if stage_str.to_s.downcase == "withdrawn"
      end

      # Group publications by document family (e.g., "R 49-1"), find the
      # latest non-withdrawn edition as "current", mark older editions as
      # "retired". Withdrawn publications stay withdrawn.
      def assign_lifecycle(publications)
        families = group_by_family(publications)
        lifecycle = {}
        families.each do |_family, editions|
          active = editions.reject { |e| e[:withdrawn] }
          current_year = active.map { |e| e[:year] }.max
          editions.each do |e|
            lifecycle[e[:id]] =
              if e[:withdrawn] then "withdrawn"
              elsif e[:year] == current_year then "current"
              else "retired"
              end
          end
        end
        publications.each { |p| p["lifecycle"] = lifecycle[p["id"]] || "current" }
      end

      def group_by_family(publications)
        families = {}
        publications.each do |p|
          m = p["id"].to_s.match(/OIML\s+([A-Z])\s*(\d+)(?:-(\d+))?:(\d{4})/)
          next unless m
          family = "#{m[1]} #{m[2]}"
          family += "-#{m[3]}" if m[3]
          families[family] ||= []
          families[family] << { id: p["id"], year: m[4].to_i, withdrawn: !!p["withdrawn"] }
        end
        families
      end

      def build_tc_sc_map(publications)
        publications.each_with_object({}) do |p, h|
          next unless p["tc_sc"] && !p["tc_sc"].to_s.strip.empty?
          h[p["id"]] = p["tc_sc"]
        end
      end
    end
  end
end
