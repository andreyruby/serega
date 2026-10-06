# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Utility to check if an object should be serialized as a collection.
    #
    # Hashes and Structs are Enumerable, but enumerate their own member
    # values, so they are treated as single objects.
    #
    # @private
    class CollectionDetector
      class << self
        #
        # Checks if provided object is a collection of objects
        #
        # @param object [Object] Object to serialize
        #
        # @return [Boolean] whether object should be serialized as a collection
        #
        def call(object)
          object.instance_of?(Array) || (object.is_a?(Enumerable) && !object.is_a?(Hash) && !object.is_a?(Struct))
        end
      end
    end
  end
end
