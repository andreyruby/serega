# frozen_string_literal: true

class Serega
  #
  # Combines attribute and nested attributes
  #
  class SeregaPlanPoint
    #
    # SeregaPlanPoint instance methods
    #
    module InstanceMethods
      # Link to current plan this point belongs to
      # @return [SeregaAttribute] Current plan
      attr_reader :plan

      # Shows current attribute
      # @return [SeregaAttribute] Current attribute
      attr_reader :attribute

      # Shows child plan if exists
      # @return [SeregaPlan, nil] Attribute serialization plan
      attr_reader :child_plan

      # Child fields to serialize
      # @return [Hash] Attributes to serialize
      attr_reader :modifiers

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
        @modifiers = modifiers
        set_normalized_vars
      end

      # Attribute `value`
      # @see SeregaAttribute::AttributeInstanceMethods#value
      def value(obj, ctx, batches: nil)
        attribute.value(obj, ctx, batches: batches)
      end

      # Attribute `name`
      # @see SeregaAttribute::AttributeInstanceMethods#value
      def name
        attribute.name
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
      # @param objects [Array] objects serialized at this point's level
      # @return [void]
      def run_preloads(objects)
        return unless preloads

        handler = self.class.serializer_class.preload_with
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
      # @return [Hash, nil] loaded data per loader name, or nil when none are needed
      def load_batches(level)
        names = batch_loaders
        return if names.empty?

        loaders = self.class.serializer_class.batch_loaders
        names.each_with_object({}) do |name, batches|
          batches[name] = level.fetch(loaders[name])
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, self)
      end

      #
      # @return [Class<SeregaObjectSerializer>] object serializer class for child plan
      #
      def child_object_serializer
        serializer::SeregaObjectSerializer
      end

      # Builds the object serializer that serializes this point's relation, or nil
      # when the point has no child plan (a plain attribute). The point owns the
      # static config (child plan, serializer class, `many`); the caller injects the
      # runtime `context` and `opts`.
      #
      # @param context [Hash] serialization context
      # @param opts [Hash] extra object-serializer options (e.g. the level queue)
      # @return [SeregaObjectSerializer, nil] serializer for the child level
      def child_serializer(context:, **opts)
        return unless child_plan

        child_object_serializer.new(context: context, plan: child_plan, many: many, **opts)
      end

      private

      def set_normalized_vars
        @child_plan = prepare_child_plan
      end

      def prepare_child_plan
        return unless serializer

        fields = modifiers || FROZEN_EMPTY_HASH

        serializer::SeregaPlan.new(self, fields)
      end
    end

    extend SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
