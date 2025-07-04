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

      # Shows preloads_path for current attribute
      # @return [Array, nil] Attribute preloads_path
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
      def value(obj, ctx)
        attribute.value(obj, ctx)
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

      #
      # @return [SeregaObjectSerializer] object serializer for child plan
      #
      def child_object_serializer
        serializer::SeregaObjectSerializer
      end

      private

      # Patched in:
      # - plugin :batch (prepares @batch)
      def set_normalized_vars
        @child_plan = prepare_child_plan
        @preloads_path = prepare_preloads_path
      end

      def prepare_child_plan
        return unless serializer

        fields = modifiers || FROZEN_EMPTY_HASH

        serializer::SeregaPlan.new(self, fields)
      end

      def prepare_preloads_path
        attribute.preloads_path
      end
    end

    extend SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
