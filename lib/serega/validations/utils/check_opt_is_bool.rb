# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    # @private
    module Utils
      #
      # Utility to check hash key value is boolean
      #
      # @private
      class CheckOptIsBool
        # Checks hash key has boolean value
        #
        # @param opts [Hash] Some options Hash
        # @param key [Object] Hash key
        #
        # @raise [Serega::SeregaError] error when provided key exists and value is not boolean
        #
        # @return [void]
        def self.call(opts, key)
          return unless opts.key?(key)

          value = opts[key]
          return if value.equal?(true) || value.equal?(false)

          raise SeregaError, "Invalid option #{key.inspect} => #{value.inspect}. Must have a boolean value"
        end
      end
    end
  end
end
