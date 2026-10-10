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
        # Checks the formatter is callable with valid parameters
        #
        # @param formatter_name [Symbol] Name of the formatter
        # @param formatter [#call] Formatter callable object
        #
        # @raise [SeregaError] Formatter validation error
        #
        # @return [void]
        #
        def call(formatter_name, formatter)
          raise SeregaError, "Option #{formatter_name.inspect} must have callable value" unless formatter.respond_to?(:call)

          signature = SeregaUtils::MethodSignature.call(formatter, pos_limit: 2, keyword_args: [:ctx])
          raise SeregaError, signature_error unless valid_signature?(signature)
        end

        private

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
