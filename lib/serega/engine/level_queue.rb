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
      end

      # Adds a level of the serializer plan. Each plan has one level, as each
      # plan belongs to one relation point.
      #
      # @param serializer [SeregaObjectSerializer] serializer that resolves the level
      # @param objects [Array] objects serialized at this level
      # @return [SeregaEngine::Level] new level
      def add(serializer, objects)
        level = Level.new(serializer, @mode, objects)
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
