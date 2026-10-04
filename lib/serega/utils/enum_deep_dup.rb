# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  # @private
  module SeregaUtils
    #
    # Duplicates nested hashes, arrays and strings
    # It does not duplicate any other values
    #
    # @private
    class EnumDeepDup
      class << self
        #
        # Deeply duplicate provided Array, Hash or String data
        # It does not duplicate any other values
        #
        # @param data [Hash, Array, String] Data to duplicate
        #
        # @return [Hash, Array, String] Duplicated data
        #
        def call(data)
          case data
          when Hash
            # https://github.com/fastruby/fast-ruby#hash-vs-hashdup-code
            data = Hash[data] # rubocop:disable Style/HashConversion
            dup_hash_values(data)
          when Array
            data = data.dup
            dup_array_values(data)
          when String
            data.dup
          else
            data
          end
        end

        private

        def dup_hash_values(data)
          data.transform_values! { |value| call(value) }
        end

        def dup_array_values(data)
          data.map! { |value| call(value) }
        end
      end
    end
  end
end
