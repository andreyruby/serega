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

      # Attribute `conditional?`
      # @see SeregaAttribute::AttributeInstanceMethods#conditional?
      def conditional?
        attribute.conditional?
      end

      #
      # @return [Boolean] Whether the object passes the :if and :unless conditions
      #
      def satisfy_if_conditions?(obj, ctx)
        check_if_unless(obj, ctx, :if, :unless)
      end

      #
      # @return [Boolean] Whether the value passes the :if_value and :unless_value conditions
      #
      def satisfy_if_value_conditions?(value, ctx)
        check_if_unless(value, ctx, :if_value, :unless_value)
      end

      private

      def check_if_unless(obj, ctx, opt_if_name, opt_unless_name)
        opt_if = attribute.opt_if[opt_if_name]
        opt_unless = attribute.opt_if[opt_unless_name]
        return true if opt_if.nil? && opt_unless.nil?

        res_if = opt_if ? check_condition(opt_if, opt_if_name, obj, ctx) : true
        res_unless = opt_unless ? !check_condition(opt_unless, opt_unless_name, obj, ctx) : true
        res_if && res_unless
      end

      def check_condition(condition, condition_name, object, context)
        signature = attribute.opt_if_signatures[condition_name]

        case signature
        when "1" then condition.call(object)
        when "2" then condition.call(object, context)
        when "1_ctx" then condition.call(object, ctx: context)
        when "2_ctx" then condition.call(object, context, ctx: context)
        else # "0"
          condition.call
        end
      end
    end

    extend SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
