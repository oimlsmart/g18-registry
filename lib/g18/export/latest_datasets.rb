# frozen_string_literal: true

require_relative "../vocabulary"

module G18
  module Export
    # Constants describing the "latest" V1/V2 editions used as the baseline
    # for alignment classification. Shape is intentionally compatible with
    # legacy call sites that expected symbol keys + indifferent access.
    module LatestDatasets
      OPT = {
        vim:  { urn: G18::Vocabulary::LATEST_VIM_URN,  dir: "vim-2012",  label: "VIM 2012"  },
        viml: { urn: G18::Vocabulary::LATEST_VIML_URN, dir: "viml-2022", label: "VIML 2022" },
      }.freeze

      def self.to_h
        OPT
      end

      def self.[](vocab)
        OPT[vocab]
      end

      def self.each(&block)
        OPT.each(&block)
      end
    end
  end
end
