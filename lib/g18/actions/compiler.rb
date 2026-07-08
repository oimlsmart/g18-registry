# frozen_string_literal: true

require_relative "action"

module G18
  module Actions
    # Computes suggested actions for each term from its pre-computed
    # data fields (official_concept, latest_check, publications,
    # source_lineage). Pure function — no I/O, no side effects.
    #
    # Usage:
    #   actions = G18::Actions::Compiler.for_term(term_hash)
    #   #=> [#<Action @type=:upgrade_vim ...>, ...]
    #
    # The caller (export_for_vite.rb) invokes this for every term and
    # stores the results in terms.json as `suggested_actions[]`.
    # UI pages filter by publication_ids or tc_sc to serve their audience.
    class Compiler
      # Normalize VIM cross-reference markup so definitions compare
      # correctly regardless of {{id,text}} wrapping.
      def self.normalize_definition(text)
        return "" unless text.is_a?(String)
        text.gsub(/\{\{[^,}]+,([^}]+)\}\}/, '\1').strip
      end

      # Returns an array of Action objects for a single term.
      # `term` is the per-term hash from data/*.yaml (the same shape
      # that export_for_vite.rb reads).
      def self.for_term(term)
        new(term).call
      end

      def initialize(term)
        @term = term || {}
        @data = @term["data"] || {}
        @pubs = @data["publications"] || []
        @oc = @data["official_concept"]
        @lc = @term["latest_check"] || @data["latest_check"]
        @kind = @data["kind"] || "undefined"
        # vocab_presence is computed at export time for undefined terms
        # (kind == "undefined"). Shape: { vim: {found, match_type, designation, ...} | nil,
        # viml: { ... } | nil }. Used to enrich action descriptions with
        # near-miss guidance so TC 1 sees "VIML term is X" inline.
        @presence = @term["vocab_presence"] || {}
      end

      def call
        actions = []
        actions.concat(vocab_actions)
        actions.concat(harmonize_action)
        actions.concat(standardize_action)
        actions.concat(unique_action) if actions.empty?
        actions.sort_by(&:priority_rank)
      end

      private

      # Vocabulary-related actions: upgrade, removed, adopt.
      def vocab_actions
        return [] unless @lc && @oc
        out = []
        vocab = @lc["vocab"]
        found = @lc["found"]
        latest = @lc["latest_label"]
        cited_label = @oc["edition_label"] || @oc["source"]
        cited_urn = @oc["source"]

        if found
          # Term exists in latest edition — check if citing an older one.
          if superseded?(cited_urn, vocab)
            action_type = vocab == "vim" ? :upgrade_vim : :upgrade_viml
            out << Action.new(
              type: action_type,
              priority: :high,
              description: "Cites #{cited_label}; available in #{latest}. Update citation.",
              publication_ids: @pubs.map { |p| p["publication_id"] }.uniq,
              vocab_ref: { "latest_label" => latest, "cited_label" => cited_label },
            )
          end
        else
          # Term not found in latest — removed or renamed.
          out << Action.new(
            type: :removed,
            priority: :high,
            description: "In #{cited_label}; removed from #{latest}. Verify or reallocate.",
            publication_ids: @pubs.map { |p| p["publication_id"] }.uniq,
            vocab_ref: { "latest_label" => latest, "cited_label" => cited_label },
          )
        end

        out
      end

      # Cross-vocabulary adoption suggestion: term is in VIM but could
      # also be in VIML (or vice versa).
      def adopt_action
        return [] unless @oc
        # If defined_in_vim and latest_check in viml found → suggest adopt_viml
        # (and vice versa). This requires the latest_check to cover BOTH
        # vocabularies. Currently latest_check only checks the SAME vocab
        # as the citation. Skip for now — the vocab repo would need to
        # populate cross-vocab latest_check data.
        []
      end

      # Terms with ≥ 2 distinct definitions WITHIN A SINGLE EDITION.
      # Cross-edition definition changes (e.g. 2010 vs 202X wording
      # differs) are NOT flagged — that's an intentional editorial change
      # between published editions, not a harmonisation failure. TC 1
      # harmonises WITHIN the 202X draft.
      def harmonize_action
        return [] if @pubs.size < 2
        per_edition = distinct_definitions_per_edition
        worst_edition, worst_count = per_edition.max_by { |_, d| d.size }
        return [] unless worst_count && worst_count.size >= 2
        pubs_in_edition = @pubs.count { |p| p["edition"] == worst_edition }
        [Action.new(
          type: :harmonize,
          priority: worst_count.size >= 5 ? :high : (worst_count.size >= 3 ? :medium : :low),
          description: "#{worst_count.size} distinct definitions within #{worst_edition} across #{pubs_in_edition} publications.",
          publication_ids: @pubs.select { |p| p["edition"] == worst_edition }
                                 .map { |p| p["publication_id"] }.uniq,
        )]
      end

      # Terms cited by ≥ 2 pubs (or the same pub across multiple editions) with
      # identical definitions — ready to standardize. The description distinguishes:
      #   - N unique pubs across M instances: "All N publications share…"
      #   - 1 unique pub cited in M editions: "Cited by 1 publication across M editions"
      # The latter is a weaker form of "standardize" (no other pub to disagree
      # with), but still useful as a stability signal.
      def standardize_action
        return [] if @pubs.size < 2
        defs = distinct_definitions
        return [] unless defs.size == 1
        unique_pub_ids = @pubs.map { |p| p["publication_id"] }.uniq
        description = if unique_pub_ids.size == 1
          "Cited by 1 publication across #{@pubs.size} editions; definition stable."
        else
          "All #{unique_pub_ids.size} publications share the same definition. Ready to standardize."
        end
        [Action.new(
          type: :standardize,
          priority: :info,
          description: description,
          publication_ids: unique_pub_ids,
        )]
      end

      # Fallback: OIML-original term with no VIM/VIML reference. The
      # description carries near-miss guidance when the export pipeline
      # found a similar VIM/VIML designation via fuzzy match — TC 1 then
      # sees concrete options (reconcile vs declare as specific V 3 term).
      def unique_action
        return [] if @oc && @kind != "undefined"
        pub_ids = @pubs.map { |p| p["publication_id"] }.uniq
        description = compose_unique_description
        [Action.new(
          type: :unique,
          priority: :info,
          description: description,
          publication_ids: pub_ids,
        )]
      end

      def compose_unique_description
        # Pick the strongest near-miss candidate (VIML > VIM for legal-
        # metrology context, exact > fuzzy for confidence).
        vim = @presence[:vim] || @presence["vim"]
        viml = @presence[:viml] || @presence["viml"]
        candidate = select_near_miss(viml, vim)
        if candidate.nil?
          "OIML-original term — no VIM/VIML reference. Candidate for V 1/V 2/V 3? Check divergent definitions and confirm authoritative source."
        elsif candidate[:match_type] == "exact" || candidate["match_type"] == "exact"
          desig = candidate[:designation] || candidate["designation"]
          vocab_label = candidate[:latest_label] || candidate["latest_label"]
          "OIML-original term, but #{vocab_label} has an exact match: '#{desig}'. Re-link to #{vocab_label} or document why this term should remain OIML-specific."
        else
          desig = candidate[:designation] || candidate["designation"]
          vocab_label = candidate[:latest_label] || candidate["latest_label"]
          "OIML-original term. #{vocab_label} has a similar term: '#{desig}'. Reconcile with #{vocab_label}, document as a specific term (candidate for V 3), or confirm OIML as authoritative."
        end
      end

      def select_near_miss(*candidates)
        # Prefer exact over fuzzy; among same match_type, prefer non-nil.
        exact = candidates.find { |c| c && (c[:match_type] || c["match_type"]) == "exact" }
        return exact if exact
        candidates.compact.first
      end

      # ── helpers ──

      def distinct_definitions
        @pubs
          .map { |p| self.class.normalize_definition(p["definition"]) }
          .reject(&:empty?)
          .uniq
      end

      # Per-edition distinct definition counts. Cross-edition definition
      # changes are legitimate editorial evolution, not harmonisation
      # targets — only WITHIN-edition divergence counts.
      def distinct_definitions_per_edition
        @pubs.group_by { |p| p["edition"] }.transform_values do |ed_pubs|
          ed_pubs
            .map { |p| self.class.normalize_definition(p["definition"]) }
            .reject(&:empty?)
            .uniq
        end
      end

      VIM_CURRENT = "urn:oiml:pub:v:2:2012"
      VIML_CURRENT = "urn:oiml:pub:v:1:2022"

      def superseded?(urn, vocab)
        return false unless urn
        current = vocab == "vim" ? VIM_CURRENT : VIML_CURRENT
        # Also handle non-URN source strings like "OIML V 2-200:2007".
        return true if urn.match?(/V 2-200:(1993|2007|2010)/) && vocab == "vim"
        return true if urn.match?(/V 1:(1968|2000|2013)/) && vocab == "viml"
        urn != current
      end
    end
  end
end
