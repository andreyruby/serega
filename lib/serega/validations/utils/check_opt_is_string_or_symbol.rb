# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Utils # :nodoc:
      #
      # Utility to check hash key value is String or Symbol
      #
      class CheckOptIsStringOrSymbol # :nodoc:
        # Checks hash key has String or Symbol value
        def self.call(opts, key)
          return unless opts.key?(key)

          value = opts[key]
          return if value.is_a?(String) || value.is_a?(Symbol)

          raise SeregaError, "Invalid option #{key.inspect} => #{value.inspect}. Must be a String or a Symbol"
        end
      end
    end
  end
end
