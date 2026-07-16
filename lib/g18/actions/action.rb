# frozen_string_literal: true

module G18
  module Actions
    # A single suggested editorial action for a term.
    # Immutable value object — computed once, consumed by many pages.
    class Action
      attr_reader :type, :priority, :description, :publication_ids, :vocab_ref

      TYPES = %i[upgrade_vim upgrade_viml removed
                 harmonize standardize unique
                 aligned definition_diverges
                 fuzzy_adopt propose_v3].freeze

      PRIORITIES = { high: 0, medium: 1, low: 2, info: 3 }.freeze

      def initialize(type:, priority:, description:, publication_ids: [], vocab_ref: nil)
        raise ArgumentError, "unknown type: #{type}" unless TYPES.include?(type.to_sym)
        @type = type.to_sym
        @priority = priority.to_sym
        @description = description
        @publication_ids = Array(publication_ids)
        @vocab_ref = vocab_ref
        freeze
      end

      def to_h
        {
          "type" => @type.to_s,
          "priority" => @priority.to_s,
          "description" => @description,
          "publication_ids" => @publication_ids,
          "vocab_ref" => @vocab_ref,
        }
      end

      def priority_rank
        PRIORITIES[@priority] || 99
      end
    end
  end
end
