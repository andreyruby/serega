# frozen_string_literal: true

class Serega
  module SeregaValidations
    module Attribute
      #
      # Attribute `:serializer` option validator
      #
      class CheckOptSerializer
        class << self
          #
          # Checks attribute :serializer option
          #
          # @param opts [Hash] Attribute options
          # @param block [nil, Proc] Attribute block (defines a nested serializer)
          #
          # @raise [SeregaError] SeregaError that option has invalid value
          #
          # @return [void]
          #
          def call(opts, block = nil)
            return unless opts.key?(:serializer)

            raise SeregaError, "Option :serializer can not be used together with block" if block

            value = opts[:serializer]
            return if valid_serializer?(value)

            raise SeregaError, "Invalid option :serializer => #{value.inspect}." \
              " Can be a Serega subclass, a String or a Proc without arguments"
          end

          private

          def valid_serializer?(value)
            value.is_a?(String) ||
              (value.is_a?(Proc) && (value.parameters.count == 0)) ||
              (value.is_a?(Class) && (value < Serega))
          end
        end
      end
    end
  end
end
