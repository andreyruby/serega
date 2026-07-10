# frozen_string_literal: true

class Serega
  module SeregaValidations
    module Attribute
      #
      # Attribute `:base_serializer` option validator
      #
      class CheckOptBaseSerializer
        class << self
          #
          # Checks attribute :base_serializer option. It specifies the parent
          # class for the nested serializer defined with the attribute block,
          # so it makes sense only when a block is provided.
          #
          # @param opts [Hash] Attribute options
          # @param block [nil, Proc] Attribute block (defines a nested serializer)
          #
          # @raise [SeregaError] SeregaError that option has invalid value
          #
          # @return [void]
          #
          def call(opts, block = nil)
            return unless opts.key?(:base_serializer)

            raise SeregaError, "Option :base_serializer can be used only with a block" unless block

            value = opts[:base_serializer]
            return if value.is_a?(Class) && (value <= Serega)

            raise SeregaError, "Invalid option :base_serializer => #{value.inspect}. Must be a Serega subclass"
          end
        end
      end
    end
  end
end
