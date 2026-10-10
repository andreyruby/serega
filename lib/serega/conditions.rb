# frozen_string_literal: true

class Serega
  #
  # The :if, :unless, :if_value and :unless_value conditions of one attribute.
  # Each object defines `#satisfy?(object, context)`, which checks :if and
  # :unless, and `#satisfy_value?(value, context)`, which checks :if_value
  # and :unless_value. Each method is one line of code at the file and line
  # of the attribute, and calls the conditions directly, for example:
  #
  #   def satisfy?(object, context) = (begin; object.active; rescue => error; ...; end)
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
      location = attribute.location
      file, _, line = location ? location.rpartition(":") : ["(attribute #{attribute.name})", nil, "1"]
      satisfy_code = "def satisfy?(object, context) = #{check_code(:if, :unless)}"
      satisfy_value_code = "def satisfy_value?(object, context) = #{check_code(:if_value, :unless_value)}"
      singleton_class.class_eval(satisfy_code, file, line.to_i)
      singleton_class.class_eval(satisfy_value_code, file, line.to_i)
    end

    private

    # Code that is true when the object passes the :if and does not match the
    # :unless condition
    def check_code(if_name, unless_name)
      checks = []
      checks << rescued_call_code(if_name) if @conditions.key?(if_name)
      checks << "!#{rescued_call_code(unless_name)}" if @conditions.key?(unless_name)
      checks.empty? ? "true" : checks.join(" && ")
    end

    # Code that calls the condition. An error raised there gets the condition
    # name.
    def rescued_call_code(name)
      "(begin; #{call_code(name)}; rescue => error; " \
        "Serega::SeregaUtils::SerializedAttributeError.condition(error, @attribute, #{name.inspect}); end)"
    end

    # Code that calls the condition with the parameters of its signature
    def call_code(name)
      condition = @conditions[name]
      keyword_code = condition.code("object") if condition.is_a?(AttributeValueResolvers::Keyword)
      return keyword_code if keyword_code

      callable = "@conditions[#{name.inspect}]"
      case SeregaUtils::MethodSignature.call(condition, pos_limit: 2, keyword_args: [:ctx])
      when "1" then "#{callable}.call(object)"
      when "2" then "#{callable}.call(object, context)"
      when "1_ctx" then "#{callable}.call(object, ctx: context)"
      when "2_ctx" then "#{callable}.call(object, context, ctx: context)"
      else "#{callable}.call" # "0"
      end
    end
  end
end
