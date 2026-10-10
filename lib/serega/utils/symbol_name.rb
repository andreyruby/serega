# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Utility to get frozen string from symbol
    #
    # @private
    class SymbolName
      class << self
        #
        # Returns frozen string corresponding to provided symbol
        #
        # @param key [Symbol]
        #
        # @return [String] frozen string corresponding to provided symbol
        #
        def call(key)
          key.is_a?(String) ? key : key.name
        end
      end
    end
  end
end
