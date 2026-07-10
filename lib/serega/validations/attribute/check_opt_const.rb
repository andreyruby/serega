# frozen_string_literal: true

class Serega
  module SeregaValidations
    module Attribute
      #
      # Attribute `:const` option validator
      #
      class CheckOptConst
        class << self
          #
          # Checks attribute :const option
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts)
            return unless opts.key?(:const)

            check_usage_with_other_params(opts)
          end

          private

          def check_usage_with_other_params(opts)
            raise SeregaError, "Option :const can not be used together with option :method" if opts.key?(:method)
            raise SeregaError, "Option :const can not be used together with option :value" if opts.key?(:value)
            raise SeregaError, "Option :const can not be used together with option :batch" if opts.key?(:batch)
          end
        end
      end
    end
  end
end
