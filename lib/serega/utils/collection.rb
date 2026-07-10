# frozen_string_literal: true

class Serega
  module SeregaUtils
    #
    # Utility to check if an object should be serialized as a collection.
    #
    # Structs are Enumerable, but enumerate their own member values,
    # so they are treated as single objects.
    #
    class Collection
      class << self
        #
        # Checks if provided object is a collection of objects
        #
        # @param object [Object] Serialized object
        #
        # @return [Boolean] whether object should be serialized as a collection
        #
        def call(object)
          object.is_a?(Enumerable) && !object.is_a?(Struct)
        end
      end
    end
  end
end
