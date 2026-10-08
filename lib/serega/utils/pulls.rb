# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Pulls of relation sources. A pull says what to take for one relation
    # source from the serialized objects of its child group:
    # - the count of a collection: an Array of this count of serialized objects
    # - SINGLE_SOURCE for one source: one serialized object
    # - nil for nil: nothing, the relation value is nil
    # - SKIP for a relation skipped by its condition: nothing, the relation
    #   value is SKIP
    #
    # @private
    module Pulls
      module_function

      #
      # Collects the sources of the relation sources, and the pull of each
      # relation source
      #
      # @param relation_sources [Array] Relation source of each source of the
      #   parent group: what the relation attribute returns
      # @param many [Boolean, nil] Whether a relation source is a collection
      #
      # @return [Array(Array, Array)] Sources, and the pull of each relation source
      #
      def collect(relation_sources, many)
        sources = []
        pulls = relation_sources.map { |relation_source| append(sources, relation_source, many) }
        [sources, pulls]
      end

      #
      # Collects like `.collect`, and keeps SKIP of a skipped relation source
      # as its pull
      #
      # @param relation_sources [Array] Relation source or SKIP of each source
      #   of the parent group
      # @param many [Boolean, nil] Whether a relation source is a collection
      #
      # @return [Array(Array, Array)] Sources, and the pull of each relation source
      #
      def collect_conditional(relation_sources, many)
        sources = []
        pulls = relation_sources.map do |relation_source|
          SeregaEngine::SKIP.equal?(relation_source) ? relation_source : append(sources, relation_source, many)
        end
        [sources, pulls]
      end

      #
      # Appends the source(s) of one relation source to sources, and returns
      # its pull
      #
      # @param sources [Array] Sources list
      # @param relation_source [Object] Relation source, or the root source(s)
      # @param many [Boolean, nil] Whether the relation source is a collection
      #
      # @return [Integer, nil, Object] Pull
      #
      def append(sources, relation_source, many)
        return if relation_source.nil?

        if many != false && CollectionDetector.call(relation_source)
          collection = relation_source.to_a
          sources.concat(collection)
          collection.size
        else
          sources << relation_source
          many ? 1 : SeregaEngine::SINGLE_SOURCE # `many` on, but a sole source was given — wrap it, don't raise
        end
      end

      #
      # Takes the relation value of each pull from the front of the
      # serialized objects. The serialized objects follow the order of the
      # pulls. Empties the serialized objects.
      #
      # @param serialized [Array<Hash, Struct, Data>] Serialized objects of the child group
      # @param pulls [Array<Integer, nil, Object>] Pulls from `.collect`
      #
      # @return [Array] Relation value of each pull
      #
      def take!(serialized, pulls)
        pulls.map do |pull|
          case pull
          when Integer then serialized.shift(pull)
          when SeregaEngine::SINGLE_SOURCE then serialized.shift
          else pull # nil or SKIP
          end
        end
      end
    end
  end
end
