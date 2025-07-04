# frozen_string_literal: true

class Serega
  module SeregaUtils
    #
    # Utility that helps to transform user provided preloads to hash
    #
    class FormatUserPreloads
      class << self
        #
        # Transforms user provided preloads to hash
        #
        # @param value [Array,Hash,String,Symbol,nil,false] preloads
        #
        # @return [Hash] preloads transformed to hash
        #
        def call(value)
          case value
          when Array then array_to_hash(value)
          when FalseClass then nil_to_hash(value)
          when Hash then hash_to_hash(value)
          when NilClass then nil_to_hash(value)
          when String then string_to_hash(value)
          when Symbol then symbol_to_hash(value)
          else raise Serega::SeregaError,
            "Preload option value can consist from Symbols, Arrays, Hashes (#{value.class} #{value.inspect} was provided)"
          end
        end

        private

        def array_to_hash(values)
          values.each_with_object({}) do |value, obj|
            obj.merge!(call(value))
          end
        end

        def hash_to_hash(values)
          values.each_with_object({}) do |(key, value), obj|
            obj[key.to_sym] = call(value)
          end
        end

        def nil_to_hash(_value)
          {}
        end

        def string_to_hash(value)
          {value.to_sym => {}}
        end

        def symbol_to_hash(value)
          {value => {}}
        end
      end
    end
  end
end
