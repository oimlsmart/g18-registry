# frozen_string_literal: true

module G18
  module Export
    # Known source-data issues corrected at export time so the UI shows
    # accurate provenance and definition-grouping. Each fixup is documented
    # so it can be removed once the source YAML in the vocab repo is
    # corrected.
    module DataFixups
      OPT = {
        # R 142-1:2025 cites V 2-200:2007 but the PDF actually references
        # VIM 3.11 which is the 2012 edition. Confirmed by user review.
        "OIML R 142-1:2025" => { ref_source: "OIML V 2-200:2012" },
        # R 99-1:2008 definition has "aquantity" (missing space) — fix to
        # match the correct "a quantity" used by the other publications.
        "OIML R 99-1:2008" => { def_fix: /aquantity/, def_replacement: "a quantity" },
      }.freeze

      # Apply fixups in-place to a publication instance hash.
      def self.apply_to_publication!(pub)
        fixup = OPT[pub["publication_id"]]
        return unless fixup
        if fixup[:ref_source] && pub["source"]&.is_a?(Hash)
          pub["source"]["ref_source"] = fixup[:ref_source]
        end
        if fixup[:def_fix] && pub["definition"]
          pub["definition"] = pub["definition"].gsub(fixup[:def_fix], fixup[:def_replacement])
        end
      end
    end
  end
end
