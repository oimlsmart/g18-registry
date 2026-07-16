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
        @kind = @data["kind"] || "oiml_original"
        @alignment = @term["alignment"] || @data["alignment"]
        # vocab_presence is computed at export time for OIML-original terms
        # (no VIM/VIML citation). Shape: { vim: {found, match_type, designation, ...} | nil,
        # viml: { ... } | nil }. Used to enrich action descriptions with
        # near-miss guidance so TC 1 sees "VIML term is X" inline.
        @presence = @term["vocab_presence"] || {}
        # canonical_mismatch is computed at export time for defined terms
        # whose latest_check found nothing. It surfaces the most-likely
        # rename candidate (e.g. "maximum permissible errors" → VIML
        # "maximum permissible measurement error") so the `removed` action
        # description can suggest "verify rename".
        @mismatch = @term["canonical_mismatch"]
      end

      def call
        @has_divergence = distinct_definitions_per_edition.values.any? { |d| d.size >= 2 }
        actions = []
        actions.concat(alignment_action)
        actions.concat(vocab_actions)
        actions.concat(harmonize_action)
        actions.concat(standardize_action)
        actions.concat(unique_action) if @kind == "oiml_original" || @kind == "undefined" || actions.empty?
        actions.sort_by(&:priority_rank)
      end

      private

      # Alignment-based actions from the 5-case classification.
      # These take priority over legacy vocab_actions when alignment
      # data is available, providing clearer guidance per the decision tree.
      def alignment_action
        return [] unless @alignment
        ac = @alignment["case"]
        status = @alignment["alignment"]
        vocab = @alignment["matched_vocab"]
        label = vocab == "viml" ? "VIML 2022" : vocab == "vim" ? "VIM 2012" : "V1/V2"
        term_name = @data["term"] || @data["name"] || "this term"

        case ac
        when 1
          [Action.new(type: :aligned, priority: :info,
            description: "Designation and definition match current #{label}. No action needed.")]
        when 3
          [Action.new(type: :definition_diverges, priority: :high,
            description: "Designation matches #{label} but definition differs. " \
                         "Adopt the #{label} concept, or differentiate the designation and propose to V3.")]
        when 4
          matched = @alignment.dig("matched_vocab") == "viml" ?
            (@term.dig("data", "vocab_presence", "viml", "designation") rescue nil) : nil
          matched ||= @term.dig("data", "vocab_presence", "vim", "designation") rescue nil
          [Action.new(type: :fuzzy_adopt, priority: :medium,
            description: "Designation is similar to a #{label} term#{matched ? " ('#{matched}')" : ''}. " \
                         "Adopt the #{label} term, or propose to V3 as sufficiently different.")]
        when 5
          [Action.new(type: :propose_v3, priority: :low,
            description: "No V1/V2 match. '#{term_name}' is OIML-specific. " \
                         "Propose for the future V3 vocabulary.")]
        else
          []
        end
      end

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
            vocab_short = vocab == :vim ? "VIM" : "VIML"
            tail = @has_divergence ?
              " Update citation, or document why divergence is intentional." :
              " Update citation."
            out << Action.new(
              type: action_type,
              priority: :high,
              description: "#{vocab_short} reference outdated — #{cited_label} superseded by #{latest}.#{tail}",
              publication_ids: @pubs.map { |p| p["publication_id"] }.uniq,
              vocab_ref: { "latest_label" => latest, "cited_label" => cited_label },
            )
          end
        else
          # Term not found in latest — removed or renamed.
          if @mismatch
            # Suggested rename candidate exists. Surface it so TC 1 can
            # decide: re-link to the canonical, or reallocate.
            tail = @has_divergence ?
              " Update or document why divergence is intentional." :
              ""
            out << Action.new(
              type: :removed,
              priority: :high,
              description: "Not in #{@mismatch["latest_label"]}. #{@mismatch["latest_label"]} term is '#{@mismatch["designation"]}'. Verify rename or reallocate.#{tail}",
              publication_ids: @pubs.map { |p| p["publication_id"] }.uniq,
              vocab_ref: { "latest_label" => @mismatch["latest_label"], "cited_label" => cited_label },
            )
          else
            # Removed without a rename candidate. Use the user's preferred
            # "Update or document why divergence is intentional" pattern
            # when divergence is also present; otherwise "Verify or
            # reallocate" remains the right guidance (no divergence to
            # document).
            tail = @has_divergence ?
              " Update the G 18 citation, or document why divergence is intentional." :
              " Verify or reallocate."
            out << Action.new(
              type: :removed,
              priority: :high,
              description: "In #{cited_label}; removed from #{latest}.#{tail}",
              publication_ids: @pubs.map { |p| p["publication_id"] }.uniq,
              vocab_ref: { "latest_label" => latest, "cited_label" => cited_label },
            )
          end
        end

        out
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
          description: "#{worst_count.size} distinct definitions within #{worst_edition} across #{pubs_in_edition} publications. Update, or document why divergence is intentional.",
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
        return [] if @oc && @kind != "oiml_original" && @kind != "undefined"
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
        vim = @presence["vim"]
        viml = @presence["viml"]
        candidate = select_near_miss(viml, vim)
        divergence_tail = @has_divergence ?
          " Check divergent definitions and update, or document why divergence is intentional." :
          " Check divergent definitions and confirm authoritative source."
        if candidate.nil?
          "Not in VIML/VIM. Candidate term for V 1/V 2/V 3?#{divergence_tail}"
        elsif candidate[:match_type] == "exact" || candidate["match_type"] == "exact"
          desig = candidate[:designation] || candidate["designation"]
          vocab_label = candidate[:latest_label] || candidate["latest_label"]
          "OIML-original term, but #{vocab_label} has an exact match: '#{desig}'. Re-link to #{vocab_label} or document why this term should remain OIML-specific.#{divergence_tail}"
        else
          desig = candidate[:designation] || candidate["designation"]
          vocab_label = candidate[:latest_label] || candidate["latest_label"]
          "OIML-original term. #{vocab_label} has a similar term: '#{desig}'. Reconcile with #{vocab_label}, document as a specific term (candidate for V 3), or confirm OIML as authoritative.#{divergence_tail}"
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
