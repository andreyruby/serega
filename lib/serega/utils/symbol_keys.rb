# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Utility to get a Hash with Symbol keys
    #
    # @private
    class SymbolKeys
      class << self
        #
        # Returns the Hash when all its keys are Symbols, or a copy with Symbol keys
        #
        # @param hash [Hash]
        #
        # @return [Hash] Hash with Symbol keys
        #
        def call(hash)
          other_key = hash.any? { |key, _value| !key.is_a?(Symbol) }
          other_key ? hash.transform_keys(&:to_sym) : hash
        end
      end
    end
  end
end
