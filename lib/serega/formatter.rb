# frozen_string_literal: true

class Serega
  #
  # Formats attribute values. A formatter is a callable that gets the value,
  # and the context when it has a second parameter or the :ctx keyword.
  #
  # @private
  class SeregaFormatter
    #
    # @param callable [#call] Callable that formats a value
    #
    def initialize(callable)
      @callable = callable
      @signature = SeregaUtils::MethodSignature.call(callable, pos_limit: 2, keyword_args: [:ctx])
    end

    #
    # Formats the value
    #
    # @param value [Object] Value to format
    # @param context [Hash] Serialization context
    #
    # @return [Object] Formatted value
    #
    def call(value, context)
      case @signature
      when "1" then @callable.call(value)
      when "1_ctx" then @callable.call(value, ctx: context)
      else @callable.call(value, context) # "2"
      end
    end
  end
end
