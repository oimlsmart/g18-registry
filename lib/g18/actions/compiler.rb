# frozen_string_literal: true

module G18
  module Actions
    # Computes suggested actions for a single term by delegating to a
    # fixed list of Rule modules. Each rule is independently testable
    # and replaceable. Adding a new rule = adding a new file under
    # `lib/g18/actions/rules/` and appending to `Rules::ALL` — no
    # existing rule needs to be modified (OCP).
    class Compiler
      # Returns an array of Action objects for a single term.
      # `term` is the per-term hash from data/*.yaml (the same shape
      # that export_for_vite.rb reads).
      def self.for_term(term)
        state = TermState.from(term)
        Rules::ALL.flat_map { |rule| rule.call(state) }.sort_by(&:priority_rank)
      end
    end
  end
end
