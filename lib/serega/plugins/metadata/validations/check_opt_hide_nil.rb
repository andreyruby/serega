# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator for meta_attribute :hide_nil option
        #
        class CheckOptHideNil # :nodoc:
          class << self
            # Checks attribute :hide_nil option
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
