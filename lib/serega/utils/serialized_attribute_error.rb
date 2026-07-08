# frozen_string_literal: true

class Serega
  module SeregaUtils
    #
    # Reraises an error, adding which attribute and serializer were being
    # serialized when it happened. Shared by the synchronous serialization walk
    # and the batch attach phase so the message stays identical for every
    # attribute, whether its value is resolved inline or during batch loading.
    #
    module SerializedAttributeError
      module_function

      #
      # @param error [Exception] Original error
      # @param point [SeregaPlanPoint] Plan point being serialized
      #
      # @return [void]
      #
      def call(error, point)
        raise error.exception(<<~MESSAGE.strip)
          #{error.message}
          (when serializing '#{point.name}' attribute in #{point.class.serializer_class})
        MESSAGE
      end
    end
  end
end
