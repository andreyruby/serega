# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # MetaAttribute `:const` option validator
        #
        class CheckOptConst # :nodoc:
          class << self
            # Checks meta_attribute :const option
            def call(opts, block = nil)
              return unless opts.key?(:const)

              check_usage_with_other_params(opts, block)
            end

            private

            def check_usage_with_other_params(opts, block)
              raise SeregaError, "Option :const can not be used together with option :value" if opts.key?(:value)
              raise SeregaError, "Option :const can not be used together with block" if block
            end
          end
        end
      end
    end
  end
end
