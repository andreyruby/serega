# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  # @private
  module SeregaEngine
    # Result of an attribute skipped by its conditions
    SKIP = Object.new.freeze

    #
    # Level-order queue of serialization levels for one serialization run.
    #
    # `#run` processes the queue in two passes. The first pass goes top-down: each
    # level runs its preloads and reads its relation values, enqueuing the related
    # objects as child levels. The second pass goes bottom-up: each level builds
    # its results, with the results of its child levels already built.
    #
    # @private
    class LevelQueue
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      def initialize(mode: :hash)
        @mode = mode
        @levels = []
        @levels_by_plan = {}.compare_by_identity
      end

      # Adds objects to the level of their plan. Objects from different
      # parents that share a plan go to one level.
      #
      # @param serializer [SeregaObjectSerializer] serializer that resolves the level
      # @param objects [Array] objects serialized at this level
      #
      # @return [Integer] index of the first added object in the level
      def enqueue(serializer, objects)
        level(serializer).add(objects)
      end

      # Returns the level of the serializer plan, and creates it on first use.
      #
      # @param serializer [SeregaObjectSerializer] serializer that resolves the level
      # @return [SeregaEngine::Level] level of the serializer plan
      def level(serializer)
        plan = serializer.plan
        level = @levels_by_plan[plan]
        return level if level

        level = Level.new(serializer, @mode)
        @levels_by_plan[plan] = level
        @levels << level
        level
      end

      # Processes every level, including child levels enqueued while processing.
      # @return [void]
      def run
        i = 0
        while i < @levels.size
          @levels[i].discover
          i += 1
        end

        @levels.reverse_each(&:build)
      end
    end
  end
end
