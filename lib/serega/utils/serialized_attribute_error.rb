# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Reraises an error, adding which attribute and serializer were being
    # serialized when it happened, and where the attribute is defined. Value
    # reads, preloads and batch loaders use it.
    #
    # @private
    module SerializedAttributeError
      module_function

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
    end
  end
end
