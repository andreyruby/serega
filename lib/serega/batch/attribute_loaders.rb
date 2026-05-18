# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  module SeregaBatch
    #
    # Batch loaders
    #
    # Remembers data required to batch load all attributes
    class AttributeLoaders
      #
      # Initializes new batch loaders
      #
      def initialize
        @point_batch_loaders = []
        @point_index = {}.compare_by_identity
      end

      # Remembers data for batch serialization:
      #
      # @param point [SeregaPlanPoint] Serialization plan point
      # @param object [Object] Serialized object
      # @param attacher [Proc] Serialized value attacher
      #
      # @return [void]
      def remember(point, object, attacher)
        point_batch_loader = point_index[point]

        unless point_batch_loader
          serializer_class = point.class.serializer_class
          point_batch_loader = serializer_class::SeregaBatchAttributeLoader.new(point)
          point_batch_loaders << point_batch_loader
          point_index[point] = point_batch_loader
        end

        point_batch_loader.store(object, attacher)
      end

      #
      # Loads all registered batches and removes them from registered list
      #
      # Iterates over each loader including loaders added during iteration
      # (child serializers discovered inside a batch flush add new loaders).
      def load_all(context)
        i = 0
        while i < point_batch_loaders.size
          point_batch_loaders[i].load_all(context)
          i += 1
        end
      end

      private

      # keeps all point_batch_loaders list
      attr_reader :point_batch_loaders

      # keeps tracking of already added serializers
      attr_reader :point_index
    end
  end
end
