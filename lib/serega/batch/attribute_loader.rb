# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  module SeregaBatch
    # Remembers data required to batch load single attribute
    class AttributeLoader
      # Instance methods for AttributeLoader
      module InstanceMethods
        # @param point [SeregaPlanPoint]
        def initialize(point)
          @point = point
          @objects = []
          @serialized_object_attachers = []
        end

        # Stores object with attacher to find and attach attribute values in batch later.
        # @param object [Object] Serialized object
        # @param attacher [Proc] Proc that attaches found values to originated attributes
        # @return [void]
        def store(object, attacher)
          objects << object
          serialized_object_attachers << [object, attacher]
        end

        # Loads serialized values for all stored objects for current attribute
        # @param context [Hash] Current serialization context
        # @return [void]
        def load_all(context)
          batches = {}
          serializer_class = point.class.serializer_class

          point.batch_loaders.each do |batch_loader_name|
            batches[batch_loader_name] ||= load_one(serializer_class, batch_loader_name, context)
          end

          serialized_object_attachers.each do |object, attacher|
            attacher.call(object, batches)
          end
        end

        private

        # Patched in:
        # - plugin :activerecord_preloads (preloads associations to found AR objects)
        def load_one(serializer_class, batch_loader_name, context)
          serializer_class.batch_loaders[batch_loader_name].load(objects, context)
        rescue => error
          reraise_with_serialized_attribute_details(error)
        end

        def reraise_with_serialized_attribute_details(error)
          raise error.exception(<<~MESSAGE.strip)
            #{error.message}
            (when serializing '#{point.name}' attribute in #{point.class.serializer_class})
          MESSAGE
        end

        attr_reader :point
        attr_reader :objects
        attr_reader :serialized_object_attachers
      end

      extend SeregaHelpers::SerializerClassHelper
      include InstanceMethods
    end
  end
end
