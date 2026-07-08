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
      # @param context [Hash] Serialization context, constant for the whole run
      #
      def initialize(context)
        @context = context
        @attribute_loaders = []
        @point_index = {}.compare_by_identity
        @levels = {}.compare_by_identity
      end

      # Gathers a chunk of objects serialized at a plan level, so every attribute at
      # that level shares one set of objects to batch load against.
      #
      # @param plan [SeregaPlan] Plan serializing these objects
      # @param objects [Array] Objects being serialized at this level
      #
      # @return [void]
      def add_objects(plan, objects)
        level_for(plan).add_objects(objects)
      end

      # Remembers data for batch serialization:
      #
      # @param point [SeregaPlanPoint] Serialization plan point
      # @param object [Object] Serialized object
      # @param attacher [Proc] Serialized value attacher
      #
      # @return [void]
      def remember(point, object, attacher)
        attribute_loader = point_index[point]

        unless attribute_loader
          serializer_class = point.class.serializer_class
          attribute_loader = serializer_class::SeregaBatchAttributeLoader.new(point, level_for(point.plan))
          attribute_loaders << attribute_loader
          point_index[point] = attribute_loader
        end

        attribute_loader.store(object, attacher)
      end

      #
      # Loads all registered batches and attaches loaded values.
      #
      # Iterates over each loader including loaders added during iteration
      # (child serializers discovered inside a batch flush add new loaders).
      def load_all
        i = 0
        while i < attribute_loaders.size
          attribute_loader = attribute_loaders[i]
          attribute_loader.attach(load_batches(attribute_loader))
          i += 1
        end
      end

      private

      # Serialization context shared by every level
      attr_reader :context

      # keeps all AttributeLoader instances
      attr_reader :attribute_loaders

      # keeps tracking of already added points
      attr_reader :point_index

      # keeps one Level per plan (compare_by_identity: plan instance identifies a level)
      attr_reader :levels

      def level_for(plan)
        levels[plan] ||= Level.new(context)
      end

      # Builds the { batch_loader_name => loaded_values } hash for one attribute.
      #
      # Loading is delegated to the attribute's Level, which loads each named batch
      # once for the whole level: attributes sharing a loader over the same objects
      # reuse a single result, deeper levels load separately.
      def load_batches(attribute_loader)
        attribute_loader.preload_associations

        point = attribute_loader.point
        serializer_class = point.class.serializer_class

        batches = {}
        point.batch_loaders.each do |batch_loader_name|
          loader = serializer_class.batch_loaders[batch_loader_name]
          batches[batch_loader_name] = attribute_loader.load_batch(loader)
        end
        batches
      end
    end
  end
end
