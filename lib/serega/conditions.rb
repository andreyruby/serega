# frozen_string_literal: true

class Serega
  #
  # The :if, :unless, :if_value and :unless_value conditions of one attribute
  #
  # @private
  class SeregaConditions
    #
    # @param attribute [SeregaAttribute] Attribute with the conditions
    # @param conditions [Hash] Callable condition of each given option
    #
    def initialize(attribute, conditions)
      @attribute = attribute
      @conditions = conditions
      @signatures = conditions.transform_values do |condition|
        SeregaUtils::MethodSignature.call(condition, pos_limit: 2, keyword_args: [:ctx])
      end
    end

    #
    # @param object [Object] Object to serialize
    # @param context [Hash] Serialization context
    #
    # @return [Boolean] Whether the object passes the :if and :unless conditions
    #
    def satisfy?(object, context)
      passes?(:if, :unless, object, context)
    end

    #
    # @param value [Object] Attribute value
    # @param context [Hash] Serialization context
    #
    # @return [Boolean] Whether the value passes the :if_value and :unless_value conditions
    #
    def satisfy_value?(value, context)
      passes?(:if_value, :unless_value, value, context)
    end

    private

    def passes?(if_name, unless_name, object, context)
      if_condition = @conditions[if_name]
      unless_condition = @conditions[unless_name]
      return true if if_condition.nil? && unless_condition.nil?

      if_result = if_condition ? call_condition(if_name, if_condition, object, context) : true
      unless_result = unless_condition ? !call_condition(unless_name, unless_condition, object, context) : true
      if_result && unless_result
    end

    def call_condition(name, condition, object, context)
      case @signatures[name]
      when "1" then condition.call(object)
      when "2" then condition.call(object, context)
      when "1_ctx" then condition.call(object, ctx: context)
      when "2_ctx" then condition.call(object, context, ctx: context)
      else # "0"
        condition.call
      end
    rescue => error
      SeregaUtils::SerializedAttributeError.condition(error, @attribute, name)
    end
  end
end
