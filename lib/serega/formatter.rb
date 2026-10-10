# frozen_string_literal: true

class Serega
  #
  # Formats attribute values. A formatter is a callable that gets the value,
  # and the context when it has a second parameter or the :ctx keyword.
  #
  # @private
  class SeregaFormatter
    # @return [#call] Callable that formats a value
    attr_reader :callable

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

    #
    # Ruby code that formats the value of `value_code` with the callable that
    # `callable_code` reads
    #
    # @param value_code [String] Code of the value to format
    # @param callable_code [String] Code of the callable
    #
    # @return [String, nil] Code, or nil when the formatter needs the context
    #
    def code(value_code, callable_code)
      "#{callable_code}.call(#{value_code})" if @signature == "1"
    end
  end
end
