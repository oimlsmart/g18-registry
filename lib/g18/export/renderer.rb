# frozen_string_literal: true

# Render stem:[<asciimath>] markup to inline MathML using Plurimath.
# Falls back to <code>stem:[...]</code> when Plurimath is unavailable
# or fails on a specific expression.
module G18
  module Export
    module Renderer
      PLURIMATH_AVAILABLE = begin
        require "plurimath"
        true
      rescue LoadError
        warn "WARNING: plurimath gem not loaded — stem:[] will render as <code>."
        false
      end

      module_function

      def render_stem(text)
        return text unless text.is_a?(String) && text.include?("stem:[")
        text.gsub(/stem:\[([^\]]+)\]/) do
          expr = $1
          if PLURIMATH_AVAILABLE
            begin
              mathml = Plurimath::Math.parse(expr, :asciimath).to_mathml
              mathml.sub('display="block"', 'display="inline"')
            rescue StandardError
              "<code>stem:[#{expr}]</code>"
            end
          else
            "<code>stem:[#{expr}]</code>"
          end
        end
      end

      def render_stem_deep(obj)
        case obj
        when String then render_stem(obj)
        when Hash   then obj.transform_values { |v| render_stem_deep(v) }
        when Array  then obj.map { |v| render_stem_deep(v) }
        else obj
        end
      end
    end
  end
end
