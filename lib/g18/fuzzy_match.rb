module G18
  module FuzzyMatch
    THRESHOLD = 0.34

    module_function

    def tokenize(s)
      s.to_s.downcase.gsub(/[^a-z0-9\s]/i, " ").split.reject { |t| t.length < 2 }
    end

    def jaccard(a, b)
      return 0.0 if a.empty? || b.empty?
      inter = (a & b).size.to_f
      union = (a | b).size.to_f
      union.positive? ? inter / union : 0.0
    end

    def match(term_name, idx, threshold: THRESHOLD)
      return nil unless idx&.any? && term_name
      term_tokens = tokenize(term_name)
      return nil if term_tokens.empty?
      best = nil
      best_score = 0.0
      idx.each do |designation, entry|
        score = jaccard(term_tokens, tokenize(designation))
        next if score <= best_score
        best_score = score
        best = { designation: designation, entry: entry, similarity: score }
      end
      return nil unless best && best_score >= threshold
      best
    end
  end
end
