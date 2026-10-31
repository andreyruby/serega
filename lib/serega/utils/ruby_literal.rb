# frozen_string_literal: true

class Serega
  module SeregaUtils # :nodoc:
    #
    # Writes values as Ruby literals in generated code
    #
    class RubyLiteral # :nodoc:
      class << self
        # Whether the value can be written as a literal: an Integer, a
        # Symbol, a String, true, false, nil or a finite Float
        def literal?(value)
          case value
          when Integer, Symbol, String, true, false, nil then true
          when Float then value.finite?
          else false
          end
        end

        # Ruby code of the literal value. A String literal is frozen, thus
        # the code makes no new String each time it runs.
        def code(value)
          value.is_a?(String) ? "#{value.inspect}.freeze" : value.inspect
        end
      end
    end
  end
end
