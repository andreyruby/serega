# frozen_string_literal: true

class Serega
  class SeregaResultCode # :nodoc:
    #
    # Code of one point in the generated methods. The local variables of the
    # point have its index in their names, for example `value_1`.
    #
    class PointCode # :nodoc:
      def initialize(point, index)
        @point = point
        @index = index
      end

      # Whether the value of the point can be SKIP
      def conditional?
        @point.conditional?
      end

      # Pair of the serialized Hash literal
      def hash_pair
        "#{@point.name.inspect} => value_#{@index}"
      end

      # Code that adds the value to the serialized Hash. It adds no key for a
      # skipped value, and with `compact` for a `nil` value.
      def hash_assign(compact)
        index = @index
        code = "serialized_hash[#{@point.name.inspect}] = value_#{index}"
        skips = []
        skips << "value_#{index}.nil?" if compact
        skips << "Serega::SeregaEngine::SKIP.equal?(value_#{index})" if conditional?
        skips.empty? ? code : "#{code} unless #{skips.join(" || ")}"
      end

      # Code of the Struct or Data argument with the value, nil for a skipped
      # value
      def argument
        return "value_#{@index}" unless conditional?

        "(Serega::SeregaEngine::SKIP.equal?(value_#{@index}) ? nil : value_#{@index})"
      end
    end
  end
end
