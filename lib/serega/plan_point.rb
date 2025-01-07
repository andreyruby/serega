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

      # Shows preloads for nested attributes
      # @return [Hash] preloads for nested attributes
      attr_reader :preloads

      # Shows preloads_path for current attribute
      # @return [Array<Symbol>, nil] preloads path for current attribute
      attr_reader :preloads_path

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

      def batch?
        !attribute.batch_loaders.empty?
      end

      # Attribute `batch_loaders`
      # @see SeregaAttribute::AttributeInstanceMethods#batch_loaders
      def batch_loaders
        attribute.batch_loaders
      end

      #
      # @return [SeregaObjectSerializer] object serializer for child plan
      #
      def child_object_serializer
        serializer::SeregaObjectSerializer
      end

      private

      def set_normalized_vars
        @child_plan = prepare_child_plan
        @preloads = prepare_preloads
        @preloads_path = prepare_preloads_path
        plan.mark_as_has_batch_points if batch?
      end

      def prepare_child_plan
        return unless serializer

        fields = modifiers || FROZEN_EMPTY_HASH

        serializer::SeregaPlan.new(self, fields)
      end

      def prepare_preloads
        SeregaUtils::PreloadsConstructor.call(child_plan)
      end

      def prepare_preloads_path
        attribute.preloads_path
      end
    end

    extend SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
