# frozen_string_literal: true

class Serega
  module SeregaFormatters # :nodoc:
    #
    # Formatter that calls a callable with the value, and with the context
    # when the callable takes it
    #
    class Callable # :nodoc:
      # Callable that formats a value
      attr_reader :callable

      def initialize(callable, allow_nil)
        @callable = callable
        @signature = SeregaUtils::MethodSignature.call(callable, pos_limit: 2, keyword_args: [:ctx])
        @allow_nil = allow_nil
      end

      # A callable formatter has no method arguments
      def args
      end

      # Formats the value
      def call(value, context)
        return if value.nil? && @allow_nil

        case @signature
        when "1" then @callable.call(value)
        when "1_ctx" then @callable.call(value, ctx: context)
        else @callable.call(value, context) # "2"
        end
      end

      # Ruby code that calls the callable that `callable_code` reads with the
      # value of `value_code`. A callable that takes the context has no code.
      def code(value_code, callable_code, _args_code)
        return unless @signature == "1"
        return "#{callable_code}.call(#{value_code})" unless @allow_nil

        "(value = #{value_code}).nil? ? nil : #{callable_code}.call(value)"
      end
    end
  end
end
