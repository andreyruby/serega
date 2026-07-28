# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    # @private
    module Utils
      #
      # Utility to check hash key value is String or Symbol
      #
      # @private
      class CheckOptIsStringOrSymbol
        # Checks hash key has String or Symbol value
        #
        # @param opts [Hash] Some options Hash
        # @param key [Object] Hash key
        #
        # @raise [Serega::SeregaError] error when provided key exists and value is not String or Symbol
        #
        # @return [void]
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
