# frozen_string_literal: true

module G18
  module Model
    # Publication ID helpers. OIML pub IDs have a recognizable shape
    # ("OIML R 76-1:2006", "OIML D 11:2004", etc.) and need consistent
    # parsing across the codebase.
    #
    # Previously these lived on G18::Migration::Loaders, but they have
    # nothing to do with glossarist loading. Moved here for MECE.
    module PubId
      module_function

      # Extracts the 4-digit year suffix from a publication ID.
      # Returns nil when no `:YYYY` suffix is present.
      #
      #   parse_year("OIML R 1:2020")      #=> 2020
      #   parse_year("OIML R 1")           #=> nil
      #   parse_year(nil)                  #=> nil
      def parse_year(s)
        m = s.to_s.match(/:(\d{4})\z/)
        m && m[1].to_i
      end

      # Normalize publication IDs to the canonical spaced format:
      # "OIML R076-1:2006" → "OIML R 76-1:2006" (space after letter,
      # no zero-pad). Empty string for nil input.
      def normalize(id)
        return "" unless id
        id.to_s
          .gsub(/OIML\s*([RDGB])\s*0*(\d)/i) { "OIML #{$1} #{$2}" }
          .gsub(/\s+/, " ")
          .strip
      end
    end
  end
end
