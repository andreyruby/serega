# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator for meta_attribute :hide_nil option
        #
        # @private
        class CheckOptHideNil
          class << self
            #
            # Checks attribute :hide_nil option
            #
            # @param opts [Hash] Attribute options
            #
            # @raise [SeregaError] SeregaError that option has invalid value
            #
            # @return [void]
            #
            def call(opts)
              return unless opts.key?(:hide_nil)

              value = opts[:hide_nil]
              return if value == true

              raise SeregaError, "Invalid option :hide_nil => #{value.inspect}. Must be true"
            end
          end
        end
      end
    end
  end
end
