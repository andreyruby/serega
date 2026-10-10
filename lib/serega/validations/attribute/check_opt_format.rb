# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    # @private
    module Attribute
      #
      # Validator for attribute :format option
      #
      # @private
      class CheckOptFormat
        class << self
          #
          # Checks attribute :format option is the name of an added formatter
          # or a valid formatter
          #
          # @param opts [Hash] Attribute options
          # @param serializer_class [Class<Serega>] Serializer of the attribute
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts, serializer_class)
            return unless opts.key?(:format)

            formatter = opts[:format]

            if formatter.is_a?(Symbol)
              check_formatter_defined(serializer_class, formatter)
            else
              CheckFormatter.call(nil, formatter)
            end
          end

          private

          def check_formatter_defined(serializer_class, formatter)
            return if serializer_class.formatters.key?(formatter)

            raise SeregaError, "Formatter `#{formatter.inspect}` was not defined"
          end
        end
      end
    end
  end
end
