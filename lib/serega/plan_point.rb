# frozen_string_literal: true

class Serega
  #
  # Combines attribute and nested attributes
  #
  # @private
  class SeregaPlanPoint
    #
    # SeregaPlanPoint instance methods
    #
    # @private
    module InstanceMethods
      # Link to current plan this point belongs to
      # @return [SeregaAttribute] Current plan
      attr_reader :plan

      # Shows current attribute
      # @return [SeregaAttribute] Current attribute
      attr_reader :attribute

      # Attribute `name`
      # @return [Symbol] Attribute name
      attr_reader :name

      # Shows child plan if exists
      # @return [SeregaPlan, nil] Attribute serialization plan
      attr_reader :child_plan

      #
      # Initializes plan point
      #
      # @param plan [SeregaPlan] Current plan this point belongs to
      # @param attribute [SeregaAttribute] Attribute to construct plan point
      # @param modifiers Serialization parameters
      # @option modifiers [Hash] :only The only attributes to serialize
      # @option modifiers [Hash] :except Attributes to hide
      # @option modifiers [Hash] :with Hidden attributes to serialize additionally
      #
      # @return [SeregaPlanPoint] New plan point
      #
      def initialize(plan, attribute, modifiers = nil)
        @plan = plan
        @attribute = attribute
        @name = attribute.name
        @child_plan = serializer::SeregaPlan.new(self, modifiers || FROZEN_EMPTY_HASH) if serializer
      end

      # Attribute `many` option
      # @see SeregaAttribute::AttributeInstanceMethods#many
      def many
        attribute.many
      end

      # Attribute `serializer` option
      # @see SeregaAttribute::AttributeInstanceMethods#serializer
      def serializer
        attribute.serializer
      end

      # Attribute `batch_loaders`
      # @see SeregaAttribute::AttributeInstanceMethods#batch_loaders
      def batch_loaders
        attribute.batch_loaders
      end

      # Attribute `preloads`
      # @see SeregaAttribute::AttributeInstanceMethods#preloads
      def preloads
        attribute.preloads
      end

      # Runs this point's declared preloads over the given objects using the
      # serializer's registered preload handler.
      #
      # Presenters are unwrapped first, as preload handlers work with the
      # serialized objects themselves.
      #
      # @param objects [Array] objects serialized at this point's level
      # @return [void]
      def run_preloads(objects)
        serializer_class = self.class.serializer_class
        objects = objects.map(&:__getobj__) if serializer_class.presenter

        handler = serializer_class.preload_with
        unless handler
          raise SeregaError, "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you)."
        end

        handler.call(objects, preloads)
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, self)
      end

      # Loads the batch loaders this point's value needs, each once for the whole
      # level, and returns them keyed by loader name for #value to read from.
      #
      # @param level [SeregaEngine::Level] level whose objects are loaded for
      # @return [Hash] loaded data per loader name
      def load_batches(level)
        loaders = self.class.serializer_class.batch_loaders
        batch_loaders.each_with_object({}) do |name, batches|
          batches[name] = level.fetch(loaders[name])
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, self)
      end

      # Builds the object serializer that serializes this point's relation. The
      # point owns the static config (child plan, serializer class, `many`); the
      # caller injects the runtime `context` and `level_queue`.
      #
      # @param context [Hash] serialization context
      # @param level_queue [SeregaEngine::LevelQueue] queue of serialization levels
      # @return [SeregaObjectSerializer] serializer for the child level
      def child_serializer(context:, level_queue:)
        serializer::SeregaObjectSerializer.new(context: context, plan: child_plan, level_queue: level_queue, many: many)
      end
    end

    extend SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
