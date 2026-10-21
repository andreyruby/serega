# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Utils # :nodoc:
      #
      # Utility to check hash key value is boolean
      #
      class CheckOptIsBool # :nodoc:
        # Checks hash key has boolean value
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
