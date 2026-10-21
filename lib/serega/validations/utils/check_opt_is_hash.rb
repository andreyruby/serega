# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Utils # :nodoc:
      #
      # Utility to check hash key value is Hash
      #
      class CheckOptIsHash # :nodoc:
        # Checks hash key value is Hash
        def self.call(opts, key)
          return unless opts.key?(key)

          value = opts[key]
          return if value.is_a?(Hash)

          raise SeregaError, "Invalid option #{key.inspect} => #{value.inspect}. Must have a Hash value"
        end
      end
    end
  end
end
