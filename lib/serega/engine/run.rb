# frozen_string_literal: true

class Serega
  #
  # Serialization engine
  #
  # @private
  module SeregaEngine
    #
    # One serialization run. Serializes the object(s) with a plan, and all
    # their related objects.
    #
    # The run keeps one object group per plan. A group holds all objects of its
    # plan, for example the posts of all users, thus batch loaders and preloads
    # run once per group. The run serializes the groups in the order it adds
    # them. A group adds the groups of its related objects when it serializes.
    #
    # @private
    class Run
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
        @object_groups_by_plan = {}.compare_by_identity
      end

      # Serializes the object(s) with the plan.
      #
      # @param plan [SeregaPlan] Serialization plan
      # @param object [Object] Serialized object(s)
      # @param many [Boolean, nil] Whether the object is a collection
      #
      # @return [Hash, Struct, Array, nil] Serialized object(s)
      def call(plan, object, many:)
        result = object_group(plan).add(object, many)
        serialize_object_groups
        result
      end

      # Returns the object group of the plan, and adds it on first use.
      #
      # @param plan [SeregaPlan] Serialization plan
      # @return [SeregaObjectGroup] Object group of the plan
      def object_group(plan)
        @object_groups_by_plan[plan] ||= add_object_group(plan)
      end

      private

      def add_object_group(plan)
        object_group = plan.serializer_class::SeregaObjectGroup.new(self, plan)
        @object_groups << object_group
        object_group
      end

      # Serializes every group, also the groups added during serialization
      def serialize_object_groups
        index = 0
        while index < @object_groups.size
          @object_groups[index].serialize
          index += 1
        end
      end
    end
  end
end
