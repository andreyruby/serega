# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  # @private
  module SeregaUtils
    #
    # Utility to freeze nested hashes and arrays
    #
    # @private
    class EnumDeepFreeze
      class << self
        #
        # Freezes nested hashes and arrays
        #
        # @param data[Hash, Array] data to freeze
        #
        # @return [Hash, Array] same deeply frozen data
        #
        def call(data)
          case data
          when Hash
            data.transform_values! { |value| call(value) }
            data.freeze
          when Array
            data.map! { |value| call(value) }
            data.freeze
          end

          data
        end
      end
    end
  end
end
