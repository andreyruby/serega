# frozen_string_literal: true

class Serega
  module SeregaValidations
    module Attribute
      #
      # Validator for attribute :preload option
      #
      class CheckOptPreload
        class << self
          #
          # Checks :preload option
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] validation error
          #
          # @return [void]
          def call(opts)
            return unless opts.key?(:preload)

            check_opt_preload(opts)
            check_usage_with_other_params(opts)
          end

          private

          def check_opt_preload(opts)
            raise SeregaError, "Option :preload value can not be `true`" if opts[:preload] == true
          end

          def check_usage_with_other_params(opts)
            raise SeregaError, "Option :preload can not be used together with option :const" if opts.key?(:const)
          end
        end
      end
    end
  end
end
