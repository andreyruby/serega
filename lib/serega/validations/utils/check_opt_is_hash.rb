# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    # @private
    module Utils
      #
      # Utility to check hash key value is Hash
      #
      # @private
      class CheckOptIsHash
        # Checks hash key value is Hash
        #
        # @param opts [Hash] Some options Hash
        # @param key [Object] Hash key
        #
        # @raise [Serega::SeregaError] error when provided key exists and value is not a Hash
        #
        # @return [void]
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
