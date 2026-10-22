# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:serializer` option validator
      #
      class CheckOptSerializer # :nodoc:
        class << self
          # Checks attribute :serializer option
          def call(opts)
            return unless opts.key?(:serializer)

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
