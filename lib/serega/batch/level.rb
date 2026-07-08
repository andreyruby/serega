# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  module SeregaBatch
    #
    # Objects serialized at one plan level, together with their loaded batch results.
    #
    # Every attribute serialized at the same level shares one Level, so a named batch
    # loader reused by several of them runs once for the whole set of objects. The same
    # loader over a different level (deeper nesting) uses a different Level and loads
    # again.
    #
    class Level
      # @return [Array] Objects gathered for this level
      attr_reader :objects

      # @param context [Hash] Serialization context
      def initialize(context)
        @context = context
        @objects = []
        @results = {}.compare_by_identity
      end

      # Adds a chunk of serialized objects to this level.
      # @param objects [Array] Objects being serialized at this level
      # @return [void]
      def add_objects(objects)
        @objects.concat(objects)
      end

      # Loads and returns values for the given batch loader, once per loader.
      #
      # Freezes the gathered objects on the first load: all of a level's objects
      # are added before any of its batches load, so sealing the set here guards
      # against a later stray `add_objects` and against a loader mutating it.
      #
      # @param loader [SeregaBatch::Loader] Named batch loader
      # @return [Object] Loaded values
      def load(loader)
        @objects.freeze
        @results[loader] ||= loader.load(@objects, @context)
      end
    end
  end
end
