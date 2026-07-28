# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  # @private
  module SeregaUtils
    #
    # Duplicates nested hashes and arrays
    # It does not duplicate any non-Array and non-Hash values
    #
    # @private
    class EnumDeepDup
      class << self
        #
        # Deeply duplicate provided Array or Hash data
        # It does not duplicate any non-Array and non-Hash values
        #
        # @param data [Hash, Array] Data to duplicate
        #
        # @return [Hash, Array] Duplicated data
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
          end

          data
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
