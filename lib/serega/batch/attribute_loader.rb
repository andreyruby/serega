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
        # @param level [SeregaBatch::Level] Shared objects and results for this point's plan level
        def initialize(point, level)
          @point = point
          @level = level
          @serialized_object_attachers = []
        end

        # Stores object with attacher to find and attach attribute values in batch later.
        # @param object [Object] Serialized object
        # @param attacher [Proc] Proc that attaches found values to originated attributes
        # @return [void]
        def store(object, attacher)
          serialized_object_attachers << [object, attacher]
        end

        # Preloads this attribute's associations onto the level's objects, once for
        # the attribute (not per named batch loader), via the serializer's registered
        # `preload_with` handler. Raises when `:preload` is declared but no handler
        # exists, so a declared preload never silently does nothing.
        # @return [void]
        def preload_associations
          preloads = point.attribute.preloads
          return unless preloads

          handler = point.class.serializer_class.preload_with
          unless handler
            raise SeregaError, "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you)."
          end

          handler.call(level.objects, preloads)
        rescue => error
          SeregaUtils::SerializedAttributeError.call(error, point)
        end

        # Loads a single named batch for this level's objects. Caching across
        # attributes that reuse the loader is handled by the Level.
        # @param loader [SeregaBatch::Loader] Named batch loader
        # @return [Object] Loaded batch values
        def load_batch(loader)
          level.load(loader)
        rescue => error
          SeregaUtils::SerializedAttributeError.call(error, point)
        end

        # Attaches already loaded batch values to every stored object.
        # Value resolution happens here (inside the attacher), so errors are
        # annotated with the attribute, matching the synchronous walk.
        # @param batches [Hash] Loaded values grouped by batch loader name
        # @return [void]
        def attach(batches)
          serialized_object_attachers.each do |object, attacher|
            attacher.call(object, batches)
          end
        rescue => error
          SeregaUtils::SerializedAttributeError.call(error, point)
        end

        attr_reader :point
        attr_reader :level

        private

        attr_reader :serialized_object_attachers
      end

      extend SeregaHelpers::SerializerClassHelper
      include InstanceMethods
    end
  end
end
