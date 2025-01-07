# frozen_string_literal: true

class Serega
  module SeregaBatch
    #
    # Automatically generated resolver for batch_loader
    #
    class AutoResolver
      attr_reader :loader_name
      attr_reader :id_method

      def initialize(loader_name, id_method)
        @loader_name = loader_name
        @id_method = id_method
      end

      # Finds object attribute value from hash of batch_loaded values for all
      # serialized objects
      def call(obj, batches:)
        batches.fetch(loader_name)[obj.public_send(id_method)]
      end
    end
  end
end
