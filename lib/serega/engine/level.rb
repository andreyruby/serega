# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  # @private
  module SeregaEngine
    #
    # One serialization level: all objects serialized under a single plan and
    # their results. Objects from different parents that share a plan accumulate
    # into one level, so a named batch loader or preload runs once over the whole
    # set.
    #
    # @private
    class Level
      # @param serializer [SeregaObjectSerializer] serializer that resolves this level
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      def initialize(serializer, mode)
        @serializer = serializer
        @mode = mode
        @objects = []
        @relation_references = nil
        @results = nil
        @loaded = {}.compare_by_identity
      end

      # @return [Array] Objects serialized at this level
      attr_reader :objects

      # @return [Array<Hash, Struct, Data>] Result per object
      attr_reader :results

      # Adds objects to this level.
      #
      # @param objects [Array] objects serialized at this level
      # @return [Integer] index of the first added object
      def add(objects)
        first_index = @objects.size
        @objects.concat(objects)
        first_index
      end

      # Runs preloads and adds levels of related objects.
      # @return [void]
      def discover
        @relation_references = @serializer.discover(self)
      end

      # Builds results of this level.
      # @return [void]
      def build
        @results = @serializer.build(self, @mode, @relation_references)
      end

      # Loads a named batch loader once for this level's objects.
      # @param loader [SeregaEngine::Loader] Named batch loader
      # @return [Object] Loaded values
      def fetch(loader)
        @loaded[loader] ||= loader.load(@objects, @serializer.context)
      end
    end
  end
end
