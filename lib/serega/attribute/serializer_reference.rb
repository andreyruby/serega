# frozen_string_literal: true

class Serega
  class SeregaAttribute # :nodoc:
    #
    # The :serializer option of an attribute: a serializer class, the name
    # of a serializer class, or a Proc that returns a serializer class. The
    # name and the Proc let serializers refer to classes defined later.
    #
    class SerializerReference # :nodoc:
      def initialize(serializer)
        @serializer = serializer
      end

      # Returns the serializer class. Resolves a name or a Proc once, and
      # keeps the class. A frozen reference, shared between Ractors,
      # resolves it on each call.
      def resolve
        serializer = @serializer
        return serializer if serializer.is_a?(Class) && serializer < Serega

        serializer = serializer.is_a?(String) ? Object.const_get(serializer, false) : serializer.call
        frozen? ? serializer : (@serializer = serializer)
      end
    end
  end
end
