# frozen_string_literal: true

class Serega
  module SeregaEngine # :nodoc:
    #
    # Pulls of relation sources. A pull says what to take for one relation
    # source from the serialized objects of its child group:
    # - the count of a collection: an Array of this count of serialized objects
    # - SINGLE_SOURCE for one source: one serialized object
    # - nil for nil: nothing, the relation value is nil
    # - SKIP for a relation skipped by its condition: nothing, the relation
    #   value is SKIP
    #
    module Pulls # :nodoc:
      # Pull of one source that is not in a collection. Its relation value is
      # one serialized object, and not an Array.
      SINGLE_SOURCE = Object.new.freeze

      module_function

      # Appends the source(s) of one relation source to sources, and returns
      # its pull. The generated `#collect` of a result builder writes the
      # same steps inline.
      def append(sources, relation_source, many, known_classes)
        return if relation_source.nil?

        if many != false && (relation_source.instance_of?(Array) || SeregaUtils::CollectionDetector.call(relation_source, known_classes))
          collection = relation_source.to_a
          sources.concat(collection)
          collection.size
        else
          sources << relation_source
          many ? 1 : SINGLE_SOURCE # `many` on, but a sole source was given — wrap it, don't raise
        end
      end

      # Takes the relation value of each pull from the front of the
      # serialized objects. The serialized objects follow the order of the
      # pulls. Empties the serialized objects.
      def take!(serialized, pulls)
        pulls.map do |pull|
          case pull
          when Integer then serialized.shift(pull)
          when SINGLE_SOURCE then serialized.shift
          else pull # nil or SKIP
          end
        end
      end
    end
  end
end
