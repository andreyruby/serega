# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Value resolver of attributes with the :batch option and without the
    # :value option. Reads the value of the object from the loaded batch.
    #
    class Batch # :nodoc:
      def initialize(loader_name, id_method)
        @loader_name = loader_name
        @id_method = id_method
      end

      #
      # Finds the object attribute value in the loaded batches
      #
      # @param obj [Object] Object to serialize
      # @param batches [Hash] Loaded batches by loader name
      # @return [Object] Attribute value
      #
      def call(obj, batches:)
        batches.fetch(@loader_name)[obj.public_send(@id_method)]
      end
    end
  end
end
