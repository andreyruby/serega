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

            raise SeregaError, "Option :preload can not be used together with option :const" if opts.key?(:const)
          end
        end
      end
    end
  end
end
