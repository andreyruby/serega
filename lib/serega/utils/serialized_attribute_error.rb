# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Reraises an error, adding which attribute and serializer were being
    # serialized when it happened, and where the attribute is defined. Value
    # reads, preloads, batch loaders and attribute conditions use it.
    #
    # @private
    module SerializedAttributeError
      module_function

      #
      # Reraises an error raised while a value is read, preloaded or batch
      # loaded
      #
      # @param error [Exception] Original error
      # @param point [SeregaPlanPoint] Plan point being serialized
      #
      # @return [void]
      #
      def call(error, point)
        location = point.attribute.location
        defined_at = location ? ", #{location}" : ""

        raise error.exception(<<~MESSAGE.strip)
          #{error.message}
          (when serializing '#{point.name}' attribute in #{point.class.serializer_class}#{defined_at})
        MESSAGE
      end

      #
      # Reraises an error raised by an :if, :unless, :if_value or
      # :unless_value condition
      #
      # @param error [Exception] Original error
      # @param point [SeregaPlanPoint] Plan point being serialized
      # @param condition_name [Symbol] Condition option name
      #
      # @return [void]
      #
      def condition(error, point, condition_name)
        location = point.attribute.location
        defined_at = location ? ", #{location}" : ""

        raise error.exception(<<~MESSAGE.strip)
          #{error.message}
          (when checking :#{condition_name} condition of '#{point.name}' attribute in #{point.class.serializer_class}#{defined_at})
        MESSAGE
      end
    end
  end
end
