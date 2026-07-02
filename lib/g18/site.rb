# frozen_string_literal: true

require "yaml"
require "set"
require "digest"
require "fileutils"
require "cgi"
require_relative "vocabulary"

module G18
  module Site
    # Captures one term in the registry, with all its publication instances.
    class Term
      attr_reader :slug, :path, :identifier, :name, :kind, :official_concept,
                  :related, :publications, :schema_id, :editions_present,
                  :primary_edition

      def initialize(slug:, identifier:, name:, kind:, official_concept:, related:, publications:, schema_id:, editions_present: nil, primary_edition: nil)
        @slug = slug
        @path = "terms/#{slug}.html"
        @identifier = identifier
        @name = name
        @kind = kind
        @official_concept = official_concept
        @related = related || []
        @publications = publications || []
        @schema_id = schema_id
        @editions_present = editions_present || []
        @primary_edition = primary_edition
      end

      def defined?
        kind == "defined_in_vim" || kind == "defined_in_viml"
      end

      def undefined?
        kind == "undefined"
      end

      def vocabulary_label
        case kind
        when "defined_in_vim"  then "VIM"
        when "defined_in_viml" then "VIML"
        else "—"
        end
      end

      def distinct_definitions
        publications.map { |p| (p["definition"] || "").strip }.reject(&:empty?).uniq
      end

      def diverges?
        distinct_definitions.size > 1
      end

      def consistency_counts
        counts = Hash.new(0)
        publications.each { |p| counts[p["consistency"] || "pending"] += 1 }
        counts
      end

      def consistency_badge
        c = consistency_counts
        return "all pending" if c.keys.all? { |k| k == "pending" }
        return "all ok" if c["ok"].to_i == publications.size
        parts = []
        parts << "#{c['ok']} ok" if c["ok"].to_i > 0
        parts << "#{c['partial']} partial" if c["partial"].to_i > 0
        parts << "#{c['ko']} ko" if c["ko"].to_i > 0
        parts << "#{c['pending']} pending" if c["pending"].to_i > 0
        parts.any? ? "mixed (#{parts.join(', ')})" : "—"
      end

      # True if this term has publications from the named edition.
      def in_edition?(name)
        publications.any? { |p| p["edition"] == name }
      end

      # Publications filtered to a specific edition.
      def publications_in_edition(name)
        publications.select { |p| p["edition"] == name }
      end

      # Distinct definitions in a given edition (or all editions if nil).
      def distinct_definitions_in_edition(name = nil)
        pubs = name ? publications_in_edition(name) : publications
        pubs.map { |p| (p["definition"] || "").strip }.reject(&:empty?).uniq
      end

      # Status relative to the two main editions.
      def edition_status
        return "only" if editions_present.size == 1
        return "both" if editions_present.size >= 2
        "none"
      end

      # Human label for the edition badge in the lede.
      def edition_badge_label
        case edition_status
        when "both" then "In 2010 + 202X"
        when "only"
          editions_present.first ? "Only in #{editions_present.first}" : "Edition unknown"
        else "No edition tagged"
        end
      end

      def self.from_hash(hash, slug)
        data = hash["data"] || {}
        new(
          slug: slug,
          identifier: data["identifier"],
          name: data["term"],
          kind: data["kind"],
          official_concept: data["official_concept"],
          related: hash["related"] || [],
          publications: data["publications"] || [],
          schema_id: hash["id"],
          editions_present: data["editions_present"] || [],
          primary_edition: data["primary_edition"],
        )
      end
    end

    # Captures one publication (e.g. "OIML R 60:2021").
    class Publication
      attr_reader :id, :reference, :link, :tc_sc, :year, :notes

      def initialize(id:, reference:, link:, tc_sc:, year:, notes: "")
        @id = id
        @reference = reference
        @link = link
        @tc_sc = tc_sc
        @year = year
        @notes = notes
      end

      def slug
        @slug ||= self.class.slugify(id)
      end

      def path
        "publications/#{slug}.html"
      end

      def attributed?
        !(tc_sc || "").strip.empty?
      end

      def self.slugify(id)
        id.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      end

      def self.from_hash(hash)
        new(
          id: hash["id"],
          reference: hash["reference"] || hash["id"],
          link: hash["link"],
          tc_sc: hash["tc_sc"] || "",
          year: hash["year"] || (hash["id"].to_s[/:(\d{4})\z/, 1]&.to_i),
          notes: hash["notes"] || "",
        )
      end
    end

    # Captures one TC/SC group (e.g. "TC 9/SC 1") with its publications and terms.
    class TcSc
      attr_reader :name, :publications, :terms

      def initialize(name:, publications:, terms:)
        @name = name
        @publications = publications
        @terms = terms
      end

      def slug
        @slug ||= self.class.slugify(name)
      end

      def path
        "tc/#{slug}.html"
      end

      def attributed?
        name != UNATTRIBUTED
      end

      def self.slugify(name)
        name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      end
    end

    UNATTRIBUTED = "(Unattributed)"

    # VIM/VIML edition helpers. Backed by G18::Vocabulary (shared with the
    # migration). These wrappers exist so existing call sites and templates
    # can stay terse: `viml_confidence_class(urn)` reads naturally.
    module_function

    def viml_vocab(urn);          G18::Vocabulary.vocab(urn); end
    def viml_year(urn);           G18::Vocabulary.year(urn); end
    def viml_role(urn);           G18::Vocabulary.role(urn); end
    def viml_label(urn);          G18::Vocabulary.label(urn); end
    def viml_confidence_class(urn); G18::Vocabulary.confidence_class(urn); end
    def viml_current?(urn);       G18::Vocabulary.current?(urn); end
    def viml_superseded?(urn);    G18::Vocabulary.superseded?(urn); end

    # Entire registry dataset, with cross-cutting indexes for rendering.
    class Dataset
      attr_reader :terms, :publications, :tcscs, :term_by_slug, :publication_by_id

      def initialize(terms:, publications:)
        @terms = terms.sort_by { |t| t.name.downcase }
        @publications = publications.sort_by { |p| [p.year || 0, p.reference] }.reverse
        @term_by_slug = terms.each_with_object({}) { |t, h| h[t.slug] = t }
        @publication_by_id = publications.each_with_object({}) { |p, h| h[p.id] = p }
        @tcscs = build_tcscs
      end

      def term_count = @terms.size
      def publication_count = @publications.size
      def instance_count = @terms.sum { |t| t.publications.size }
      def defined_term_count = @terms.count(&:defined?)
      def divergent_term_count = @terms.count(&:diverges?)

      def attributed_publication_count = @publications.count(&:attributed?)
      def attributed_term_instance_count
        @terms.sum { |t| t.publications.count { |p| publication_by_id[p["publication_id"]]&.attributed? } }
      end

      # Edition-aware counts. Each Term carries `editions_present`; each
      # publication carries `edition`. These helpers power the side-by-side
      # edition comparison on the home page.
      def edition_names
        @terms.flat_map { |t| t.editions_present }.compact.uniq.sort
      end

      def instances_in_edition(name)
        @terms.sum { |t| t.publications.count { |p| p["edition"] == name } }
      end

      def terms_only_in_edition(name)
        @terms.count { |t| t.editions_present == [name] }
      end

      def terms_in_both_editions
        @terms.count { |t| t.editions_present.size > 1 }
      end

      # "Harmonization candidates": terms with multiple publications from
      # DISTINCT source documents (i.e. the same designation cited by
      # multiple OIML publications with potentially divergent definitions).
      # These are the worklist for TC 1's harmonisation of g18-202X.
      def harmonization_candidates
        @terms.select do |t|
          distinct_pubs = t.publications.map { |p| p["publication_id"] }.compact.uniq
          distinct_pubs.size > 1
        end
      end

      # Harmonization candidates filtered to a specific edition.
      def harmonization_candidates_in_edition(name)
        harmonization_candidates.select do |t|
          t.publications.any? { |p| p["edition"] == name }
        end
      end

      def leaderboard(limit = 20)
        @terms
          .select { |t| t.publications.size > 1 }
          .sort_by { |t| [-(t.distinct_definitions.size), -(t.publications.size), t.name.downcase] }
          .first(limit)
      end

      def terms_for_publication(pub_id)
        @terms.select { |t| t.publications.any? { |p| p["publication_id"] == pub_id } }
          .sort_by { |t| t.name.downcase }
      end

      def publications_for_term(term)
        term.publications.sort_by { |p| [-((p["year"] || 0)), p["publication_id"].to_s] }
      end

      def terms_for_tc(tc)
        tc.terms.sort_by { |t| t.name.downcase }
      end

      def divergence_for(term)
        defs = term.distinct_definitions
        return [] if defs.size <= 1
        defs
      end

      private

      def build_tcscs
        # Map: tc_sc name -> { publications: Set, term_slugs: Set }
        buckets = Hash.new { |h, k| h[k] = { publications: [], term_slugs: Set.new } }
        @publications.each do |pub|
          tc = pub.attributed? ? pub.tc_sc : UNATTRIBUTED
          buckets[tc][:publications] << pub
        end
        @terms.each do |term|
          term.publications.each do |p|
            pub = publication_by_id[p["publication_id"]]
            next unless pub
            tc = pub.attributed? ? pub.tc_sc : UNATTRIBUTED
            buckets[tc][:term_slugs] << term.slug
          end
        end
        buckets.map do |name, data|
          TcSc.new(
            name: name,
            publications: data[:publications].sort_by { |p| [-(p.year || 0), p.reference] },
            terms: data[:term_slugs].map { |s| term_by_slug[s] }.compact.sort_by { |t| t.name.downcase },
          )
        end.sort_by { |t| t.name == UNATTRIBUTED ? "zzz" : t.name }
      end
    end

    module_function

    def load_dataset(data_dir:, bib_path:)
      publications = load_publications(bib_path)
      terms = load_terms(data_dir)
      Dataset.new(terms: terms, publications: publications)
    end

    def load_publications(bib_path)
      entries = YAML.safe_load(File.read(bib_path), aliases: true) || []
      entries.map { |e| Publication.from_hash(e) }
    end

    def load_terms(data_dir)
      Dir.glob(File.join(data_dir, "*.yaml")).sort.map do |file|
        slug = File.basename(file, ".yaml")
        hash = YAML.safe_load(File.read(file), aliases: true) || {}
        Term.from_hash(hash, slug)
      end
    end
  end
end
