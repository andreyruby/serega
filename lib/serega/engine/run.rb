# frozen_string_literal: true

class Serega
  #
  # Serialization engine
  #
  # @private
  module SeregaEngine
    # Reference to the serialized object of one object. A reference to the
    # serialized objects of a collection is the count of its objects.
    SINGLE_OBJECT = -1

    #
    # One serialization run. Serializes the object(s) with a plan, and all
    # their related objects.
    #
    # The run keeps object groups. A group holds all objects of one plan, for
    # example the posts of all users, thus batch loaders and preloads run once
    # per group. The run serializes the groups in two passes:
    # - Discover pass, from the root group down. Each group runs its preloads
    #   and adds one child group of related objects per relation.
    # - Build pass, from the last group up. Each group builds its serialized
    #   objects. The serialized related objects are ready at this time.
    #
    # @private
    class Run
      # Serializes the object(s) with the plan in a new run.
      #
      # @param plan [SeregaPlan] Serialization plan
      # @param object [Object] Object(s) to serialize
      # @param many [Boolean, nil] Whether the object is a collection
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param context [Hash] Serialization context
      #
      # @return [Hash, Struct, Data, Array, nil] Serialized object(s)
      def self.call(plan, object, many:, mode:, context:)
        new(mode: mode, context: context).call(plan, object, many: many)
      end

      # Serialization mode
      # @return [Symbol] :hash, :data or :struct
      attr_reader :mode

      # Serialization context
      # @return [Hash] Serialization context
      attr_reader :context

      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param context [Hash] Serialization context
      def initialize(mode:, context:)
        @mode = mode
        @context = context
        @object_groups = []
      end

      # Serializes the object(s) with the plan.
      #
      # @param plan [SeregaPlan] Serialization plan
      # @param object [Object] Object(s) to serialize
      # @param many [Boolean, nil] Whether the object is a collection
      #
      # @return [Hash, Struct, Data, Array, nil] Serialized object(s)
      def call(plan, object, many:)
        objects = []
        reference = collect(object, many, objects)
        return if reference.nil?

        root_group = add_object_group(plan, objects, [reference])
        discover_object_groups
        @object_groups.reverse_each(&:build)
        root_group.relation_values[0]
      end

      # Adds a group of objects of the plan.
      #
      # @param plan [SeregaPlan] Serialization plan
      # @param objects [Array] Objects to serialize
      # @param references [Array<Integer, nil, Object>] References from
      #   #collect, one per object of the parent group
      # @return [SeregaObjectGroup] New object group
      def add_object_group(plan, objects, references)
        object_group = plan.serializer_class::SeregaObjectGroup.new(self, plan, objects, references)
        @object_groups << object_group
        object_group
      end

      # Adds the object(s) to the objects list.
      #
      # @param object [Object] Object(s) to serialize
      # @param many [Boolean, nil] Whether the object is a collection
      # @param objects [Array] Objects list
      #
      # @return [Integer, nil] Reference to the serialized objects:
      #   SINGLE_OBJECT, count of objects of a collection, or nil for nil
      def collect(object, many, objects)
        return if object.nil?

        if many != false && (object.instance_of?(Array) || SeregaUtils::CollectionDetector.call(object))
          collection = object.to_a
          objects.concat(collection)
          collection.size
        else
          objects << object
          many ? 1 : SINGLE_OBJECT # `many` on, but a sole object was given — wrap it, don't raise
        end
      end

      private

      # Discovers every group, also the groups added during discovery
      def discover_object_groups
        index = 0
        while index < @object_groups.size
          @object_groups[index].discover
          index += 1
        end
      end
    end
  end
end
