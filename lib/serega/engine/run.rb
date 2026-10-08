# frozen_string_literal: true

class Serega
  #
  # Serialization engine
  #
  # @private
  module SeregaEngine
    # Pull of one source that is not in a collection. Its relation value is
    # one serialized object, and not an Array.
    SINGLE_SOURCE = -1

    # Value of an attribute skipped by its :if, :unless, :if_value or
    # :unless_value condition. It is also the pull of a skipped relation.
    SKIP = Object.new.freeze

    #
    # One serialization run. Serializes the source(s) with a plan, and all
    # their relation sources. A source is an object to serialize.
    #
    # The run makes source groups. A group holds all sources of one plan, for
    # example the posts of all users, thus batch loaders and preloads run once
    # per group. The run serializes the groups in two passes:
    # - Discover pass, from the root group down. Each group runs its preloads
    #   and makes one child group per relation.
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
      end

      # Serializes the object(s) with the plan.
      #
      # @param plan [SeregaPlan] Serialization plan
      # @param object [Object] Object(s) to serialize
      # @param many [Boolean, nil] Whether the object is a collection
      #
      # @return [Hash, Struct, Data, Array, nil] Serialized object(s)
      def call(plan, object, many:)
        return if object.nil?

        root_group = root_source_group(plan, object, many)
        source_groups = discover(root_group)
        build(source_groups)
        root_value(root_group)
      end

      # Makes a source group of the plan.
      #
      # @param plan [SeregaPlan] Serialization plan
      # @param sources [Array] Sources
      # @param pulls [Array<Integer, nil, Object>] Pulls from
      #   `SeregaSourceGroup.collect`, one per source of the parent group
      # @return [SeregaSourceGroup] New source group
      def new_source_group(plan, sources, pulls)
        plan.serializer_class::SeregaSourceGroup.new(self, plan, sources, pulls)
      end

      private

      # Makes the root group: the root source(s) with one pull
      def root_source_group(plan, object, many)
        sources = []
        pull = plan.serializer_class::SeregaSourceGroup.append_sources(sources, object, many)
        new_source_group(plan, sources, [pull])
      end

      # Discovers the root group and its child groups, from the root down.
      # Returns all groups in discover order: a child group comes after its
      # parent group.
      def discover(root_group)
        source_groups = [root_group]
        index = 0

        while index < source_groups.size
          source_groups.concat(source_groups[index].discover)
          index += 1
        end

        source_groups
      end

      # Builds the groups from the last one up, thus a child group is built
      # before its parent group
      def build(source_groups)
        source_groups.reverse_each(&:build)
      end

      # Returns the serialized root: one serialized object for SINGLE_SOURCE,
      # or all serialized objects of the root group
      def root_value(root_group)
        serialized = root_group.serialized
        (root_group.pulls[0] == SINGLE_SOURCE) ? serialized[0] : serialized
      end
    end
  end
end
