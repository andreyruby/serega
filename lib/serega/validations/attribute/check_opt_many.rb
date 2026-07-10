# frozen_string_literal: true

class Serega
  module SeregaValidations
    module Attribute
      #
      # Attribute `:many` option validator
      #
      class CheckOptMany
        class << self
          #
          # Checks attribute :many option
          #
          # @param opts [Hash] Attribute options
          # @param block [nil, Proc] Attribute block
          #
          # @raise [SeregaError] SeregaError that option has invalid value
          #
          # @return [void]
          #
          def call(opts, block = nil)
            return unless opts.key?(:many)

            check_many_option_makes_sence(opts, block)
            Utils::CheckOptIsBool.call(opts, :many)
          end

          private

          def check_many_option_makes_sence(opts, block)
            return if many_option_makes_sence?(opts, block)

            raise SeregaError, "Option :many can be provided only together with :serializer, :batch option or a block"
          end

          def many_option_makes_sence?(opts, block)
            opts[:serializer] || opts[:batch] || block
          end
        end
      end
    end
  end
end
