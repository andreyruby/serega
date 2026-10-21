# frozen_string_literal: true

class Serega
  module SeregaUtils # :nodoc:
    #
    # Utility to check if an object should be serialized as a collection.
    #
    # Hashes and Structs are Enumerable, but enumerate their own member
    # values, so they are treated as single objects.
    #
    class CollectionDetector # :nodoc:
      # Number of classes a Hash of known classes keeps
      MAX_KNOWN_CLASSES = 8

      class << self
        # Checks if provided object is a collection of objects. Remembers the
        # answer for the class of the object in `known_classes`, up to
        # MAX_KNOWN_CLASSES classes: `is_a?(Enumerable)` checks all
        # ancestors of a class that does not include Enumerable.
        def call(object, known_classes)
          return true if object.instance_of?(Array)

          object_class = object.class
          collection = known_classes[object_class]
          return collection unless collection.nil?

          collection = object.is_a?(Enumerable) && !object.is_a?(Hash) && !object.is_a?(Struct)
          known_classes[object_class] = collection if known_classes.size < MAX_KNOWN_CLASSES
          collection
        end
      end
    end
  end
end
