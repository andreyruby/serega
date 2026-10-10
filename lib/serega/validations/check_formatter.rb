# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    #
    # Validator for formatters defined with `Serega.formatter` or given
    # directly as the attribute :format option
    #
    # @private
    class CheckFormatter
      class << self
        #
        # Checks the formatter is a callable with valid parameters, a method
        # name, or an Array of a method name and its arguments. The attribute
        # :format option also accepts a Hash with one of them as :use and the
        # :allow_nil option.
        #
        # @param formatter_name [Symbol, nil] Name of the formatter, nil for the
        #   attribute :format option
        # @param formatter [#call, Symbol, Array, Hash] Formatter
        #
        # @raise [SeregaError] Formatter validation error
        #
        # @return [void]
        #
        def call(formatter_name, formatter)
          if formatter.is_a?(Hash) && !formatter_name
            Utils::CheckAllowedKeys.call(formatter, %i[use allow_nil], :formatter)
            Utils::CheckOptIsBool.call(formatter, :allow_nil)
            formatter = formatter[:use]
          end

          check_value(formatter_name, formatter)
        end

        private

        def check_value(formatter_name, formatter)
          return if formatter.is_a?(Symbol)
          return if formatter.is_a?(Array) && formatter.first.is_a?(Symbol)
          raise SeregaError, invalid_formatter(formatter_name) unless formatter.respond_to?(:call)

          signature = SeregaUtils::MethodSignature.call(formatter, pos_limit: 2, keyword_args: [:ctx])
          raise SeregaError, signature_error unless valid_signature?(signature)
        end

        def valid_signature?(signature)
          case signature
          when "1"      # (value)
            true
          when "2"      # (value, context)
            true
          when "1_ctx"  # (value, :ctx)
            true
          else
            false
          end
        end

        def invalid_formatter(formatter_name)
          return invalid_format_option unless formatter_name

          <<~ERROR.strip
            Invalid formatter #{formatter_name.inspect}. A formatter must be one of:
            - a callable, for example ->(value) { value.round(2) }
            - a method name, for example :to_s
            - an Array of a method name and its arguments, for example [:round, 2]
          ERROR
        end

        def invalid_format_option
          <<~ERROR.strip
            Invalid attribute option :format. It must be a formatter name or one of:
            - a callable, for example ->(value) { value.round(2) }
            - an Array of a method name and its arguments, for example [:round, 2]
            - a Hash with one of them or a method name as :use and the :allow_nil option, for example {use: :to_s, allow_nil: true}
          ERROR
        end

        def signature_error
          <<~ERROR.strip
            Invalid formatter parameters, valid parameters signatures:
            - (value)          # one positional parameter
            - (value, context) # two positional parameters
            - (value, :ctx)    # one positional parameter and :ctx keyword
          ERROR
        end
      end
    end
  end
end
