# frozen_string_literal: true

require_relative "../vocabulary"
require_relative "../fuzzy_match"

module G18
  module Export
    # Pure-function matching: classification of an OIML term against the
    # latest V1/V2 designation indices. Produces a 5-case alignment
    # classification consumed by both the Actions::Compiler and the UI.
    #
    # The 5 cases:
    #   1. aligned       — designation + normalized definition match current
    #   2. historic      — matches only historic V1/V2 (handled separately)
    #   3. diverges      — designation matches, definition differs
    #   4. fuzzy         — designation has a fuzzy match in current
    #   5. none          — no match at all
    module Matcher
      module_function

      # Normalizes a definition string for comparison. Strips cross-ref
      # markup ({{id,text}} → text in caller; here we strip entirely for
      # a more lenient match), punctuation, and collapses whitespace.
      def normalize_definition(text)
        return "" unless text
        text.to_s
          .gsub(/\{\{[^}]+\}\}/, "")
          .gsub(/[^a-z0-9\s]/i, " ")
          .split
          .join(" ")
          .downcase
          .strip
      end

      # Look up a term in its cited vocabulary's latest index. Used for
      # terms whose `official_concept` carries a V1/V2 URN — we want to
      # confirm the concept still exists at the same id (or any id) in
      # the latest edition.
      #
      # Returns a hash with `found: true` + lookup info, or `found: false`.
      def check_latest_edition(term_name, official_urn, concept_id, latest_indices, latest_datasets)
        return nil unless official_urn && term_name
        vocab = G18::Vocabulary.vocab(official_urn)
        return nil unless vocab
        info = latest_datasets[vocab]
        return nil unless info
        idx = latest_indices[vocab]
        return nil unless idx&.any?
        lookup = term_name.to_s.downcase.strip

        entry = idx[lookup]
        entry ||= idx.values.find { |v| v[:id] == concept_id } if concept_id
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

      # Classify a term's alignment against V1 and V2 (both). Returns a
      # hash with per-vocab match info and the best (lowest) case number.
      # `term_definition` is optional; when supplied it distinguishes
      # cases 1 (aligned) vs 3 (diverges).
      def classify_alignment(term_name, term_definition, latest_indices, latest_full_concepts, latest_datasets)
        result = { "vim" => nil, "viml" => nil, "case" => 5, "alignment" => "none" }
        return result unless term_name
        best_case = 5
        best_match = nil
        norm_def = normalize_definition(term_definition)

        %w[vim viml].each do |vocab|
          v = vocab.to_sym
          idx = latest_indices[v] || latest_indices[vocab]
          next unless idx&.any?
          full = latest_full_concepts[v] || latest_full_concepts[vocab] || {}
          info = latest_datasets[v]
          next unless info
          lookup = term_name.to_s.downcase.strip

          if idx.key?(lookup)
            entry = idx[lookup]
            full_concept = full[entry[:id]]
            match = build_vocab_match(entry, full_concept, info, term_name, "exact")
            vocab_def = normalize_definition(entry[:definition])
            if !vocab_def.empty? && vocab_def == norm_def
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
            next unless m
            full_concept = full[m[:entry][:id]]
            match = build_vocab_match(m[:entry], full_concept, info, m[:designation], "fuzzy", m[:similarity])
            match["alignment"] = "fuzzy"
            result[vocab] = match
            if 4 < best_case
              best_case = 4
              best_match = vocab
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
    end
  end
end
