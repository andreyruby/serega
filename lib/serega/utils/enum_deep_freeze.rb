# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  # @private
  module SeregaUtils
    #
    # Utility to freeze nested hashes, arrays and strings
    #
    # @private
    class EnumDeepFreeze
      class << self
        #
        # Freezes nested hashes and arrays, replaces strings with frozen copies
        #
        # @param data [Hash, Array, String] data to freeze
        #
        # @return [Hash, Array, String] deeply frozen data
        #
        def call(data)
          case data
          when Hash
            data.transform_values! { |value| call(value) }
            data.freeze
          when Array
            data.map! { |value| call(value) }
            data.freeze
          when String
            -data
          else
            data
          end
        end
      end
    end
  end
end
