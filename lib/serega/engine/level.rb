# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  module SeregaEngine
    #
    # One serialization level: all objects serialized under a single plan and the
    # result containers they fill. Objects from different parents that share a plan
    # (e.g. every user's posts) accumulate into one level, so a named batch loader
    # or preload runs once over the whole set. A deeper level (its own plan) loads
    # separately.
    #
    class Level
      # @param serializer [SeregaObjectSerializer] serializer that resolves this level
      def initialize(serializer)
        @serializer = serializer
        @objects = []
        @containers = []
        @results = {}.compare_by_identity
      end

      # @return [Array] Objects serialized at this level
      attr_reader :objects

      # @return [Array<Hash>] Result container per object (filled in place)
      attr_reader :containers

      # Accumulates a chunk of objects into this level, creating one empty result
      # container per object. The containers are returned so the caller can hand
      # them to its parent; they are filled in place later during #process.
      #
      # @param objects [Array] objects serialized at this level
      # @return [Array<Hash>] the created containers, aligned with objects
      def add(objects)
        containers = Array.new(objects.size) { {} }
        @objects.concat(objects)
        @containers.concat(containers)
        containers
      end

      # Resolves every attribute of this level onto the containers.
      # @return [void]
      def process
        @serializer.process(self)
      end

      # Loads a named batch loader once for this level's objects.
      # @param loader [SeregaEngine::Loader] Named batch loader
      # @return [Object] Loaded values
      def fetch(loader)
        @results[loader] ||= loader.load(@objects, @serializer.context)
      end
    end
  end
end
