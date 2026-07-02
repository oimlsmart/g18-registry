# frozen_string_literal: true

# Shared metadata about OIML VIM and VIML editions used by both the
# migration (which embeds edition info in per-term YAML) and the site
# renderer (which colours and warns based on edition age).
#
# Editions are listed oldest-first. The last entry in each vocab is the
# current "latest authoritative definition" that the registry treats as
# the baseline for consistency comparison.
module G18
  module Vocabulary
    VIM_EDITIONS = {
      "urn:oiml:pub:v:2:1993" => { year: 1993, role: :legacy },
      "urn:oiml:pub:v:2:2007" => { year: 2007, role: :prior },
      "urn:oiml:pub:v:2:2010" => { year: 2010, role: :prior },
      "urn:oiml:pub:v:2:2012" => { year: 2012, role: :current },
    }.freeze

    VIML_EDITIONS = {
      "urn:oiml:pub:v:1:1968" => { year: 1968, role: :legacy },
      "urn:oiml:pub:v:1:2000" => { year: 2000, role: :prior },
      "urn:oiml:pub:v:1:2013" => { year: 2013, role: :prior },
      "urn:oiml:pub:v:1:2022" => { year: 2022, role: :current },
    }.freeze

    LATEST_VIM_URN  = "urn:oiml:pub:v:2:2012"
    LATEST_VIML_URN = "urn:oiml:pub:v:1:2022"

    def self.all_editions
      VIM_EDITIONS.merge(VIML_EDITIONS)
    end

    def self.info(urn)
      all_editions[urn] || {}
    end

    # `:vim` or `:viml`, or nil for unknown URNs.
    def self.vocab(urn)
      return :vim  if VIM_EDITIONS.key?(urn)
      return :viml if VIML_EDITIONS.key?(urn)
      nil
    end

    def self.role(urn); info(urn)[:role]; end
    def self.year(urn); info(urn)[:year]; end

    # Short human label, e.g. "VIM 2012" or "VIML 2022".
    def self.label(urn)
      v = vocab(urn); y = year(urn)
      v && y ? "#{v.to_s.upcase} #{y}" : nil
    end

    # True if the URN represents the current/latest authoritative edition
    # of its vocabulary.
    def self.current?(urn)
      urn == LATEST_VIM_URN || urn == LATEST_VIML_URN
    end

    # True if the URN represents an edition that has been superseded by a
    # newer one within the same vocabulary.
    def self.superseded?(urn)
      role(urn) == :prior || role(urn) == :legacy
    end

    # CSS class string for visual styling. Nil for unknown URNs.
    def self.confidence_class(urn)
      v = vocab(urn); r = role(urn)
      v && r ? "viml-ref #{v}-#{r}" : nil
    end
  end
end