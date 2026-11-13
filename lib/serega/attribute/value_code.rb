# frozen_string_literal: true

class Serega
  class SeregaAttribute # :nodoc:
    #
    # Ruby code that reads the value of an attribute from the `source`
    # variable of generated code. The `:const` and `:default` values and
    # the formatters come from the
    # `CONSTANTS`, `DEFAULTS`, `FORMATTERS` and `FORMATTER_ARGS` of
    # SeregaAttributeValues, which `constants_prefix` names.
    #
    class ValueCode # :nodoc:
      def initialize(name, value_block, default, formatter)
        @name = name
        @value_block = value_block
        @default = default
        @formatter = formatter
      end

      # Code that reads the value of the source with a resolver, nil
      # for a :value callable and for a resolver without code
      def plain(constants_prefix = "")
        resolver = @value_block
        return unless resolver.is_a?(AttributeValueResolvers::Base)

        code = resolver.const? ? "#{constants_prefix}CONSTANTS[#{@name.inspect}]" : resolver.code("source")
        code && finish(code, constants_prefix)
      end

      # Code that calls the :value callable, which `callable_variable`
      # holds. `batches_variable` holds the loaded batches. nil without the
      # :value option.
      def callable(callable_variable, batches_variable, constants_prefix)
        callable = @value_block
        return unless callable.is_a?(AttributeValueResolvers::Callable)

        finish(callable.code("source", callable_variable, batches_variable), constants_prefix)
      end

      # Code that reads the value of a :batch attribute without the :value
      # option from the loaded batch, which `batch_variable` holds. nil for
      # other attributes.
      def batch(batch_variable, constants_prefix)
        resolver = @value_block
        return unless resolver.is_a?(AttributeValueResolvers::Batch)

        finish(resolver.batch_code("source", batch_variable), constants_prefix)
      end

      private

      # Adds the `:default` value and the formatter to the code that reads
      # the value. nil for a formatter that takes the context.
      def finish(code, constants_prefix)
        name = @name.inspect
        code = "(value = #{code}).nil? ? #{constants_prefix}DEFAULTS[#{name}] : value" unless @default.nil?
        return code unless @formatter

        @formatter.code(code, "#{constants_prefix}FORMATTERS[#{name}]", "#{constants_prefix}FORMATTER_ARGS[#{name}]")
      end
    end
  end
end
