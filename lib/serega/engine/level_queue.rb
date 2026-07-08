# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  module SeregaEngine
    #
    # Level-order queue of serialization levels for one serialization run.
    #
    # `#serialize` on the object serializer enqueues a level (objects + their result
    # containers) instead of resolving values inline. `#run` then processes the
    # queue: each level resolves its attributes and, for relations, enqueues child
    # levels — which the loop picks up because it re-reads the size each iteration.
    # Processing level-by-level lets a named batch loader and preloads run once per
    # level over all of its objects.
    #
    class LevelQueue
      def initialize
        @levels = []
        @levels_by_plan = {}.compare_by_identity
      end

      # Adds objects to the level for their plan (creating it on first use), so
      # objects serialized under the same plan — even from different parents —
      # share one level and load once. The level creates a result container per
      # object and returns them for the caller to embed in its parent.
      #
      # @param serializer [SeregaObjectSerializer] serializer that resolves the level
      # @param objects [Array] objects serialized at this level
      #
      # @return [Array<Hash>] the created result containers, aligned with objects
      def enqueue(serializer, objects)
        level = @levels_by_plan[serializer.plan]
        unless level
          level = Level.new(serializer)
          @levels_by_plan[serializer.plan] = level
          @levels << level
        end
        level.add(objects)
      end

      # Processes every level, including child levels enqueued while processing.
      # @return [void]
      def run
        i = 0
        while i < @levels.size
          @levels[i].process
          i += 1
        end
      end
    end
  end
end
