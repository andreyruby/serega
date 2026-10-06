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
        @child_plan = serializer ? serializer::SeregaPlan.new(self, modifiers || FROZEN_EMPTY_HASH) : nil
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
    end

    extend SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
