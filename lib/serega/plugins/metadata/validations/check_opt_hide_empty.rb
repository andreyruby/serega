# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator for meta_attribute :hide_empty option
        #
        # @private
        class CheckOptHideEmpty
          class << self
            #
            # Checks attribute :hide_empty option
            #
            # @param opts [Hash] Attribute options
            #
            # @raise [SeregaError] SeregaError that option has invalid value
            #
            # @return [void]
            #
            def call(opts)
              return unless opts.key?(:hide_empty)

              value = opts[:hide_empty]
              return if value == true

              raise SeregaError, "Invalid option :hide_empty => #{value.inspect}. Must be true"
            end
          end
        end
      end
    end
  end
end
