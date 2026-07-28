# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Utility to get frozen string from symbol in any ruby version
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
          key.is_a?(String) ? key : to_frozen_string(key)
        end

        private

        # :nocov:
        if RUBY_VERSION < "3"
          def to_frozen_string(key)
            key.to_s.freeze
          end
        else
          def to_frozen_string(key)
            key.name
          end
        end
        # :nocov:
      end
    end
  end
end
